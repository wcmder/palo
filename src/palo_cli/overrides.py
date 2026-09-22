"""Preview and update device variables beneath an existing Panorama stack."""
import argparse
import ipaddress
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path

from .panorama_api import APIError, PanoramaAPI

BASE = "/config/devices/entry[@name='localhost.localdomain']"
HOST_FIELDS = {'default_gateway'}
FIELDS = HOST_FIELDS | {
    'wan_ip', 'lan_ip', 'mgmt_ip', 'tunnel_ip',
    'spoke_a_tunnel_ip', 'spoke_b_tunnel_ip',
}


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate JSON key: ' + key)
        result[key] = value
    return result


def load_devices(path, selected=None):
    try:
        devices = json.loads(path.read_text(), object_pairs_hook=unique_object)
    except OSError:
        raise ValueError('Cannot read override file: ' + str(path)) from None
    except json.JSONDecodeError:
        raise ValueError('Override file must contain valid JSON.') from None
    if not isinstance(devices, dict):
        raise ValueError('Override file must be an object keyed by device name.')
    seen = set()
    for name, item in devices.items():
        if not re.fullmatch(r'[A-Za-z0-9_-]+', name):
            raise ValueError('Device keys must contain only letters, numbers, underscore or hyphen.')
        if not isinstance(item, dict) or set(item) != {'serial', 'template_stack', 'var'}:
            raise ValueError(name + ': require serial, template_stack and var only.')
        for field in ['serial', 'template_stack']:
            value = item[field]
            if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9_. -]+', value) or value != value.strip():
                raise ValueError(name + ': invalid ' + field)
        if item['serial'] in seen:
            raise ValueError('Each serial must occur only once in the override file.')
        seen.add(item['serial'])
        values = item['var']
        if not isinstance(values, dict) or not values or set(values) - FIELDS:
            raise ValueError(name + ': unsupported variable; allowed: ' +
                             ', '.join(sorted(FIELDS)))
        for field, value in values.items():
            if value is None:  # Explicit reset to inheritance.
                continue
            try:
                if not isinstance(value, str):
                    raise ValueError()
                if field in HOST_FIELDS:
                    ipaddress.IPv4Address(value)
                else:
                    if '/' not in value:
                        raise ValueError()
                    ipaddress.IPv4Interface(value)
            except ValueError:
                raise ValueError(name + ': ' + field + ' requires IPv4' + (' address.' if field in HOST_FIELDS else ' address/prefix.')) from None
        wan, gateway = values.get('wan_ip'), values.get('default_gateway')
        if wan is not None and gateway is not None:
            interface = ipaddress.IPv4Interface(wan)
            address = ipaddress.IPv4Address(gateway)
            if address not in interface.network or address == interface.ip:
                raise ValueError(name + ': gateway must be a different address in the WAN subnet.')
    if selected:
        if selected not in devices:
            raise ValueError('Unknown device key: ' + selected)
        return {selected: devices[selected]}
    return devices


def stack_path(name):
    # Input validation excludes quotes and XPath metacharacters.
    return BASE + "/template-stack/entry[@name='%s']" % name


def variable_path(item, field):
    return stack_path(item['template_stack']) + "/devices/entry[@name='%s']/variable/entry[@name='$%s']" % (item['serial'], field)


def entry_value(entry):
    if entry is None:
        return None
    kind = entry.find('type')
    if kind is None or len(kind) != 1 or kind[0].tag != 'ip-netmask':
        raise ValueError('Existing override has an unexpected variable type; no automatic conversion is supported.')
    return kind[0].text or ''


def preview(api, devices):
    """Validate all selected targets before permitting any writes."""
    stacks, templates, changes = {}, {}, []
    for name, item in devices.items():
        stack_name = item['template_stack']
        if stack_name not in stacks:
            stacks[stack_name] = api.get(stack_path(stack_name)).find('./result/entry')
        stack = stacks[stack_name]
        if stack is None:
            raise ValueError(name + ': template stack does not exist; apply Terraform first.')
        device = next((e for e in stack.findall('./devices/entry') if e.get('name') == item['serial']), None)
        if device is None:
            raise ValueError(name + ': serial is not assigned to this stack; apply Terraform first.')
        definitions = {e.get('name'): e for e in stack.findall('./variable/entry')}
        for member in stack.findall('./templates/member'):
            template = member.text
            if not template or not re.fullmatch(r"[A-Za-z0-9_. -]+", template):
                raise ValueError('Unsupported template name in Panorama.')
            if template not in templates:
                templates[template] = api.get(BASE + "/template/entry[@name='%s']/variable" % template)
            for entry in templates[template].findall('./result/variable/entry'):
                definitions.setdefault(entry.get('name'), entry)
        for field, desired in item['var'].items():
            variable = '$' + field
            definition = definitions.get(variable)
            if definition is None:
                raise ValueError(name + ': missing inherited variable ' + variable)
            entry_value(definition)  # Require an IP Netmask definition.
            current = next((e for e in device.findall('./variable/entry') if e.get('name') == variable), None)
            before = entry_value(current)
            if before != desired:
                changes.append({'device': name, 'item': item, 'field': field, 'before': before, 'after': desired})
    return changes


def apply_changes(api, changes):
    completed = 0
    for change in changes:
        path = variable_path(change['item'], change['field'])
        # Stop if another administrator changed a value since preview.
        current = entry_value(api.get(path).find('./result/entry'))
        if current != change['before']:
            raise ValueError('Override changed since preview; stop and run overrides plan again. Earlier writes, if any, remain in candidate configuration.')
        try:
            if change['after'] is None:
                api.request(type='config', action='delete', xpath=path)
            else:
                kind = ET.Element('type')
                ET.SubElement(kind, 'ip-netmask').text = change['after']
                api.set(path, ET.tostring(kind, encoding='unicode'))
            actual = entry_value(api.get(path).find('./result/entry'))
            if actual != change['after']:
                raise APIError('Override read-back did not match the requested value.')
        except APIError:
            raise APIError('Override update/verification failed after %d verified writes. Candidate configuration may be partially updated; run overrides plan before retrying. No commit or push was performed.' % completed) from None
        completed += 1
    return completed


def parser():
    result = argparse.ArgumentParser(prog='palo <environment> overrides', description='Manage per-device Panorama IP variable overrides. No commit or push.')
    result.add_argument('operation', choices=['plan', 'apply'])
    result.add_argument('--file', default='device_overrides.json', help='JSON file relative to the selected environment (or absolute path).')
    result.add_argument('--device', help='Select one device key, such as paa.')
    return result


def run(options, root, environ, api_factory=PanoramaAPI):
    path = Path(options.file).expanduser()
    if not path.is_absolute():
        path = root / path
    devices = load_devices(path, options.device)
    if not devices:
        print('No device overrides configured.')
        return 0
    api = api_factory(environ)
    changes = preview(api, devices)
    for change in changes:
        before = change['before'] if change['before'] is not None else '(inherited)'
        after = change['after'] if change['after'] is not None else '(inherit)'
        print('%s [%s] $%s: %s -> %s' % (change['device'], change['item']['serial'], change['field'], before, after))
    if not changes:
        print('No changes. Selected device overrides match Panorama candidate configuration.')
    elif options.operation == 'apply':
        count = apply_changes(api, changes)
        print('Updated and verified %d candidate variable overrides. Commit and push separately.' % count)
    else:
        print('%d variable override changes. No writes performed.' % len(changes))
    return 0

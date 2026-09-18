"""Onboard firewalls through the PAN-OS XML API, outside Terraform state."""
import argparse
from datetime import datetime, timedelta, timezone
import ipaddress
import json
import os
import re
import sys
import tempfile
import time
import uuid
import xml.etree.ElementTree as ET

from .panorama_api import APIError, PanoramaAPI
from .serials import load_devices, unique_object

class OnboardingError(ValueError):
    """A locally composed message safe to display without server response data."""


DEVICES = '/config/mgt-config/devices'
SYSTEM = "/config/devices/entry[@name='localhost.localdomain']/deviceconfig/system"


def bounded_integer(low, high):
    def parse(value):
        try:
            number = int(value)
            if low <= number <= high:
                return number
        except ValueError:
            pass
        raise argparse.ArgumentTypeError(f'Use an integer from {low} to {high}.')
    return parse


def parser():
    result = argparse.ArgumentParser(prog='palo <environment> onboard', description='Discover serials, register with Panorama, configure and commit firewalls, and optionally verify connectivity.')
    result.add_argument('operation', choices=['plan', 'apply'])
    result.add_argument('--auto-approve', action='store_true', help='Skip apply confirmation, including full candidate commits.')
    result.add_argument('--lifetime-minutes', type=bounded_integer(5, 525600), default=60)
    result.add_argument('--key-count', type=bounded_integer(1, 100), default=100, help='Total registration uses for the shared key (default 100).')
    result.add_argument('--batch-size', type=bounded_integer(1, 100), default=50, help='Maximum firewalls per shared key (default 50; also capped by --key-count).')
    result.add_argument('--connection-check', action='store_true', help='Wait for Panorama to report devices connected after commits (skipped by default).')
    result.add_argument('--timeout', type=bounded_integer(1, 3600), default=600, help='Seconds to wait for each commit and, with --connection-check, final connections.')
    return result


def xml(tag, values):
    root = ET.Element(tag)
    for path, value in values.items():
        node = root
        for part in path.split('/'):
            found = node.find(part)
            node = found if found is not None else ET.SubElement(node, part)
        node.text = str(value)
    return ET.tostring(root, encoding='unicode')


def save_json(path, data):
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=path.parent, prefix='.' + path.stem + '-', suffix='.tmp', delete=False) as file:
            temporary = file.name
            os.fchmod(file.fileno(), 0o600)
            json.dump(data, file, indent=2, sort_keys=True)
            file.write('\n')
        os.replace(temporary, path)
        temporary = None
    finally:
        if temporary is not None:
            os.unlink(temporary)


def connected_serials(api):
    response = api.request(type='op', cmd='<show><devices><all></all></devices></show>')
    devices = response.find('./result/devices')
    if devices is None:
        raise APIError('Panorama returned an unexpected managed-device status response.')
    return {entry.findtext('serial') or entry.get('name') for entry in devices.findall('entry') if entry.findtext('connected') == 'yes'}


def preflight(root, child):
    config = json.loads((root / 'palo.json').read_text(), object_pairs_hook=unique_object)
    try:
        ip = str(ipaddress.ip_address(config.get('panorama_ip', config['hostname'])))
    except (ValueError, TypeError):
        raise OnboardingError('Set panorama_ip in palo.json to the IP firewalls use to reach Panorama.') from None
    print('[palo] Inspecting Panorama connectivity and managed devices...', flush=True)
    try:
        panorama = PanoramaAPI(child)
        known = connected_serials(panorama)
        configured = panorama.get(DEVICES)
    except APIError as exc:
        raise OnboardingError('Panorama: ' + (exc.diagnostic or 'API request failed; check connectivity and API permissions.')) from None
    registered = {e.get('name') for e in configured.findall('./result/devices/entry')}
    firewalls = {}
    seen = set()
    for name, host in sorted(load_devices(root).items()):
        print(f'[palo] Inspecting {name}...', flush=True)
        try:
            api = PanoramaAPI(dict(child, PANOS_HOSTNAME=host))
            info = api.request(type='op', cmd='<show><system><info></info></system></show>')
            serial = (info.findtext('./result/system/serial') or '').strip()
            if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]*', serial) or serial.lower() in {'unknown', 'none', 'null'}:
                raise OnboardingError(f'{name}: no valid serial returned.')
            if serial in seen:
                raise OnboardingError('Two inventory entries returned the same serial; fix the device map.')
            seen.add(serial)
            # Check candidate and running settings. Never silently migrate another manager.
            for action in ['get', 'show']:
                response = api.request(type='config', action=action, xpath=SYSTEM)
                for field in ['panorama/local-panorama/panorama-server', 'panorama/local-panorama/panorama-server-2', 'panorama-server', 'panorama-server-2']:
                    server = response.findtext('./result/system/' + field)
                    if server and server != ip:
                        raise OnboardingError(f'{name}: already configured for another Panorama or HA peer; migration is not supported by this command.')
        except APIError as exc:
            raise OnboardingError(f'{name} ({host}): ' + (exc.diagnostic or 'API request failed; check connectivity and API permissions.')) from None
        firewalls[name] = {'api': api, 'host': host, 'serial': serial, 'connected': serial in known, 'registered': serial in registered}
    return panorama, ip, firewalls


def extract_key(response):
    for path in ['./result/authkey/entry/key', './result/authkey', './result/key', './result/entry/key']:
        value = response.findtext(path)
        if value and value.strip():
            return value.strip()
    result = response.find('result')
    text = '\n'.join(result.itertext()) if result is not None else ''
    # PAN-OS operational responses can contain CLI-formatted text.
    found = re.search(r"Added authkey\s+'[^']+':\s*'([^']+)'", text)
    if found is None:
        found = re.search(r'^\s*Key\s*:\s*(\S+)\s*$', text, re.MULTILINE)
    if found is None:
        message = 'Registration key response was not recognized. The key name was saved; inspect it on Panorama before retrying.'
        raise APIError(message, diagnostic=message)
    return found.group(1)


def key_valid(entry, options):
    return (bool(entry.get('key_name')) and len(entry['key_name']) <= 31
            and bool(entry.get('expires_at'))
            and datetime.fromisoformat(entry['expires_at']) > datetime.now(timezone.utc)
            and entry.get('count') == options.key_count)


def batches(pending, journal, options):
    """Preserve usable saved key groups when some devices have already connected."""
    remaining = dict(sorted(pending.items()))
    size = min(options.batch_size, options.key_count)
    result = []
    for entry in journal.get('registration_keys', {}).values():
        if not key_valid(entry, options):
            continue
        names = [name for name, device in remaining.items() if device['serial'] in entry.get('serials', [])]
        for offset in range(0, len(names), size):
            group = {name: remaining.pop(name) for name in names[offset:offset + size]}
            result.append((group, entry))
    names = list(remaining)
    for offset in range(0, len(names), size):
        result.append(({name: remaining[name] for name in names[offset:offset + size]}, None))
    return result


def registration_key(api, devices, journal, path, options, entry=None):
    now = datetime.now(timezone.utc)
    serials = sorted(device['serial'] for device in devices.values())
    entry = entry or {}
    valid = key_valid(entry, options)
    valid = valid and set(serials).issubset(entry.get('serials', []))
    valid = valid and entry.get('count') == options.key_count
    if not valid:
        entry = {'serials': serials, 'key_name': 'palo-' + uuid.uuid4().hex[:26],
                 'count': options.key_count,
                 'expires_at': (now + timedelta(minutes=options.lifetime_minutes)).isoformat(),
                 'stage': 'creating_key'}
        journal.setdefault('registration_keys', {})[entry['key_name']] = entry
        save_json(path, journal)  # Persist the key name before the remote side effect.
        command = ET.fromstring(xml('request', {
            'authkey/add/name': entry['key_name'], 'authkey/add/lifetime': options.lifetime_minutes,
            'authkey/add/count': options.key_count, 'authkey/add/devtype': 'fw',
        }))
        allowed = ET.SubElement(command.find('authkey/add'), 'serial')
        for serial in serials:
            ET.SubElement(allowed, 'member').text = serial
        response = api.request(type='op', cmd=ET.tostring(command, encoding='unicode'))
        try:
            entry['auth_key'] = extract_key(response)
        except APIError:
            # Some versions acknowledge creation without returning the secret.
            response = api.request(type='op', cmd=xml('request', {'authkey/list': entry['key_name']}))
            entry['auth_key'] = extract_key(response)
    elif not entry.get('auth_key'):
        response = api.request(type='op', cmd=xml('request', {'authkey/list': entry['key_name']}))
        entry['auth_key'] = extract_key(response)
    entry['stage'] = 'key_saved'
    for name, device in devices.items():
        journal['devices'][name] = {'serial': device['serial'], 'host': device['host'],
                                    'key_name': entry['key_name'], 'stage': 'key_saved'}
    # Migrate legacy per-device secrets to shared batch records. Previously
    # generated keys on Panorama are not revoked; they expire independently.
    for device in journal['devices'].values():
        for field in ['auth_key', 'expires_at']:
            device.pop(field, None)
    save_json(path, journal)
    return entry['auth_key']


def wait_job(api, job_id, timeout, label):
    deadline = time.monotonic() + timeout
    print(f'[palo] {label}: waiting for commit job {job_id}...', flush=True)
    while True:
        response = api.request(type='op', cmd=xml('show', {'jobs/id': job_id}))
        job = response.find('./result/job')
        if job is None:
            raise APIError(f'{label}: commit job status is missing.')
        if job.findtext('status') == 'FIN':
            if job.findtext('result') != 'OK':
                raise APIError(f'{label}: commit job {job_id} failed. Inspect its details on the device.')
            return
        if time.monotonic() >= deadline:
            raise APIError(f'{label}: timed out waiting for job {job_id}; it may still be running.')
        time.sleep(2)


def commit(api, label, journal, path, timeout):
    response = api.request(type='commit', cmd='<commit></commit>')
    job = response.findtext('./result/job')
    if not job:
        # PAN-OS code 19 and no job means there were no changes to commit.
        if response.get('code') == '19':
            return
        raise APIError(f'{label}: commit returned no job ID; verify the result before proceeding.')
    journal.setdefault('jobs', {})[label] = job
    save_json(path, journal)
    wait_job(api, job, timeout, label)
    del journal['jobs'][label]
    save_json(path, journal)


def run(options, root, child):
    path = root / 'onboarding.json'
    stage = 'preflight'
    try:
        panorama, ip, devices = preflight(root, child)
        pending = {name: d for name, d in devices.items() if not d['connected']}
        journal = {'panorama': child['PANOS_HOSTNAME'], 'panorama_ip': ip, 'devices': {}, 'jobs': {}}
        if path.exists():
            journal = json.loads(path.read_text(), object_pairs_hook=unique_object)
            if journal.get('panorama') != child['PANOS_HOSTNAME'] or journal.get('panorama_ip') != ip or not isinstance(journal.get('devices'), dict) or not isinstance(journal.get('jobs', {}), dict):
                raise OnboardingError('onboarding.json does not match this Panorama; review the saved file.')
        keys = journal.setdefault('registration_keys', {})
        legacy = journal.pop('registration_key', None)
        if legacy:
            keys.setdefault(legacy['key_name'], legacy)
        planned_batches = batches(pending, journal, options)
        for name, device in pending.items():
            saved = journal['devices'].get(name, {})
            if saved and (saved.get('serial') != device['serial'] or saved.get('host') != device['host']):
                raise OnboardingError(f'{name}: inventory differs from onboarding.json; review the saved record before retrying.')
        for name, d in devices.items():
            print(f"  {name}: {d['serial']} — {'already connected; skip' if d['connected'] else 'onboard'}")
        print(f'[palo] {len(planned_batches)} batch(es), at most {min(options.batch_size, options.key_count)} firewalls per batch.')
        print('[palo] Apply uses shared batch keys restricted to their serials, registers devices, and commits the FULL candidate configuration on Panorama and each pending firewall, including existing pending edits. No policy/template push is performed.')
        if options.operation == 'plan':
            return 0
        if not options.auto_approve and input('Proceed with onboarding and these commits? Type "yes": ') != 'yes':
            print('[palo] Onboarding cancelled.')
            return 0
        save_json(root / 'serial.json', {name: d['serial'] for name, d in devices.items()})
        save_json(path, journal)
        # Resolve previously recorded jobs before issuing further configuration changes.
        for label, job in list(journal.get('jobs', {}).items()):
            api = panorama if label == 'Panorama' else devices[label.removeprefix('firewall:')]['api']
            wait_job(api, job, options.timeout, label)
            del journal['jobs'][label]
            save_json(path, journal)
        if not pending:
            print('[palo] All devices are already connected; no onboarding changes needed.')
            return 0
        for batch_index, (batch, saved_key) in enumerate(planned_batches, 1):
            print(f'[palo] Processing batch {batch_index}/{len(planned_batches)} ({len(batch)} firewalls)...', flush=True)
            stage = f'batch {batch_index}: generating/saving shared registration key'
            key = registration_key(panorama, batch, journal, path, options, saved_key)
            for name, d in batch.items():
                stage = f'{name}: registering serial on Panorama'
                if not d['registered']:
                    entry = ET.Element('entry', name=d['serial'])
                    panorama.set(DEVICES, ET.tostring(entry, encoding='unicode'))
            stage = 'Panorama commit'
            commit(panorama, 'Panorama', journal, path, options.timeout)
            for name, d in batch.items():
                stage = f'{name}: configuring Panorama and committing firewall'
                d['api'].request(type='op', cmd=xml('request', {'authkey/set': key}))
                # Merge only the Panorama address; preserve other system settings.
                d['api'].set(SYSTEM + '/panorama', xml('local-panorama', {'panorama-server': ip}))
                commit(d['api'], 'firewall:' + name, journal, path, options.timeout)
                journal['devices'][name]['stage'] = 'firewall_committed'
                save_json(path, journal)
        if not options.connection_check:
            print('[palo] Onboarding configuration committed. Connection check skipped; devices may still be connecting. serial.json and private onboarding.json saved.')
            return 0
        stage = 'connection verification'
        deadline = time.monotonic() + options.timeout
        remaining = dict(pending)
        print('[palo] Waiting for Panorama to report the firewalls connected...', flush=True)
        while remaining:
            connected = connected_serials(panorama)
            for name in list(remaining):
                if remaining[name]['serial'] in connected:
                    journal['devices'][name]['stage'] = 'connected'
                    save_json(path, journal)
                    print(f'[palo] {name}: connected.', flush=True)
                    del remaining[name]
            if not remaining:
                break
            if time.monotonic() >= deadline:
                raise OnboardingError('Connection verification timed out for: ' + ', '.join(remaining))
            time.sleep(2)
        print('[palo] Onboarding complete. serial.json and private onboarding.json saved.')
        return 0
    except (EOFError, KeyboardInterrupt):
        print(f'[palo] Interrupted during {stage}. Remote jobs may continue; inspect onboarding.json and device jobs before retrying.', file=sys.stderr)
        return 130
    except OnboardingError as exc:
        print(f'[palo] {exc}', file=sys.stderr)
        if stage == 'preflight':
            print('[palo] Preflight stopped. No onboarding writes or commits were performed.', file=sys.stderr)
        else:
            print(f'[palo] Stopped during {stage}; inspect saved progress before retrying. No automatic rollback is performed.', file=sys.stderr)
        return 1
    except APIError as exc:
        print(f'[palo] {stage}: {exc.diagnostic or "API request failed; inspect the device job/API permissions."}', file=sys.stderr)
        print('[palo] Stopped; earlier changes are not rolled back. Inspect saved progress before retrying.', file=sys.stderr)
        return 1
    except (ValueError, OSError, KeyError, TypeError):
        # Never print server replies, keys, or journal values in errors.
        print(f'[palo] Onboarding failed during {stage}. Check inventory, API access, saved progress and device jobs. Earlier changes are not rolled back; onboarding.json may contain a recoverable key.', file=sys.stderr)
        return 1

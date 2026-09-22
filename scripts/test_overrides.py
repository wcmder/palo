import copy
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, Mock, MagicMock
import xml.etree.ElementTree as ET

from palo_cli import overrides as ov
from palo_cli.panorama_api import PanoramaAPI, APIError, NoRedirect


DEVICE = {'serial': 'serial-a', 'template_stack': 'shared-stack', 'var': {'wan_ip': '10.0.1.2/24', 'lan_ip': '10.1.1.2/24', 'default_gateway': '10.0.1.1'}}
STACK = '''<response status="success"><result><entry name="shared-stack">
<templates><member>shared-network</member></templates><devices>
<entry name="serial-a"><variable><entry name="$wan_ip"><type><ip-netmask>10.0.1.3/24</ip-netmask></type></entry>
<entry name="$unrelated"><type><fqdn>keep.example</fqdn></type></entry></variable></entry>
<entry name="serial-b"/></devices></entry></result></response>'''
TEMPLATE = '<response status="success"><result><variable>' + ''.join('<entry name="$%s"><type><ip-netmask>None</ip-netmask></type></entry>' % f for f in ['wan_ip', 'lan_ip', 'mgmt_ip', 'default_gateway']) + '</variable></result></response>'


class FakeAPI:
    def __init__(self):
        self.stack = ET.fromstring(STACK)
        self.writes = []

    def get(self, path):
        if '/template/' in path:
            return ET.fromstring(TEMPLATE)
        if '/variable/entry' not in path:
            return copy.deepcopy(self.stack)
        serial = path.rsplit("/devices/entry[@name='", 1)[1].split("']")[0]
        field = path.split("/variable/entry[@name='")[1].split("']")[0]
        device = self.stack.find("./result/entry/devices/entry[@name='%s']" % serial)
        value = device.find("./variable/entry[@name='%s']" % field)
        response = ET.fromstring('<response status="success"><result/></response>')
        if value is not None:
            response.find('result').append(copy.deepcopy(value))
        return response

    def set(self, path, element):
        self.writes.append((path, element))
        serial = path.rsplit("/devices/entry[@name='", 1)[1].split("']")[0]
        field = path.split("/variable/entry[@name='")[1].split("']")[0]
        device = self.stack.find("./result/entry/devices/entry[@name='%s']" % serial)
        variables = device.find('variable')
        if variables is None:
            variables = ET.SubElement(device, 'variable')
        entry = variables.find("./entry[@name='%s']" % field)
        if entry is None:
            entry = ET.SubElement(variables, 'entry', name=field)
        for child in list(entry):
            entry.remove(child)
        entry.append(ET.fromstring(element))

    def request(self, **params):
        assert params['action'] == 'delete'
        path = params['xpath']
        self.writes.append((path, None))
        serial = path.rsplit("/devices/entry[@name='", 1)[1].split("']")[0]
        field = path.split("/variable/entry[@name='")[1].split("']")[0]
        variables = self.stack.find("./result/entry/devices/entry[@name='%s']/variable" % serial)
        variables.remove(variables.find("./entry[@name='%s']" % field))


class OverridesTest(unittest.TestCase):
    def load(self, value):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'devices.json'
            path.write_text(json.dumps(value))
            return ov.load_devices(path)

    def test_validation_and_multiple_devices(self):
        b = copy.deepcopy(DEVICE)
        b['serial'] = 'serial-b'
        b['var'] = {'wan_ip': '10.2.1.2/24', 'default_gateway': '10.2.1.1'}
        self.assertEqual(len(self.load({'paa': DEVICE, 'pab': b})), 2)
        for field, value in [('serial', "x']/bad"), ('var', {'wan_ip': '10.0.1.2'}), ('var', {'unknown': 'x'}), ('var', {'wan_ip': 'None'}), ('var', {'wan_ip': '10.0.1.2/24', 'default_gateway': '10.2.1.1'})]:
            bad = copy.deepcopy(DEVICE)
            bad[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                self.load({'bad': bad})
        with self.assertRaises(ValueError):
            self.load({'a': DEVICE, 'b': DEVICE})

    def test_management_override(self):
        device = copy.deepcopy(DEVICE)
        device['var'] = {'mgmt_ip': '10.1.10.2/24'}
        devices = self.load({'paa': device})
        api = FakeAPI()
        changes = ov.preview(api, devices)
        self.assertEqual(ov.apply_changes(api, changes), 1)
        self.assertEqual(api.stack.findtext(".//entry[@name='$mgmt_ip']/type/ip-netmask"), '10.1.10.2/24')
        self.assertEqual(ov.preview(api, devices), [])

    def test_bgp_variable_validation(self):
        device = copy.deepcopy(DEVICE)
        device['var'] = {
            'local_bgp_asn': '65001',
            'remote_bgp_asn': '65003',
            'spoke_a_remote_bgp_asn': '65001',
            'spoke_b_remote_bgp_asn': '65002',
            'bgp_router_id': '10.255.13.1',
            'remote_bgp_peer_ip': '10.255.13.3',
        }
        self.assertEqual(self.load({'paa': device})['paa'], device)
        for field, value in [
            ('local_bgp_asn', '0'),
            ('local_bgp_asn', '4294967295'),
            ('local_bgp_asn', '1.10'),
            ('local_bgp_asn', 'None'),
            ('local_bgp_asn', 65001),
            ('bgp_router_id', '10.255.13.1/24'),
            ('remote_bgp_peer_ip', '10.255.13.3/24'),
        ]:
            bad = copy.deepcopy(device)
            bad['var'][field] = value
            with self.subTest(field=field, value=value):
                with self.assertRaises(ValueError):
                    self.load({'paa': bad})

    def test_asn_apply_reset_and_type_mismatch(self):
        device = copy.deepcopy(DEVICE)
        device['var'] = {'local_bgp_asn': '65001'}
        template = TEMPLATE.replace(
            '</variable>',
            '<entry name="$local_bgp_asn"><type><as-number>None</as-number>'
            '</type></entry></variable>',
        )
        api = FakeAPI()
        with patch(__name__ + '.TEMPLATE', template):
            changes = ov.preview(api, self.load({'paa': device}))
            self.assertEqual(ov.apply_changes(api, changes), 1)
            self.assertIn('<as-number>65001</as-number>', api.writes[0][1])
            self.assertEqual(ov.preview(api, {'paa': device}), [])
            device['var']['local_bgp_asn'] = None
            changes = ov.preview(api, {'paa': device})
            self.assertEqual(ov.apply_changes(api, changes), 1)
            self.assertEqual(ov.preview(api, {'paa': device}), [])
        wrong = template.replace('as-number', 'ip-netmask')
        with patch(__name__ + '.TEMPLATE', wrong):
            with self.assertRaises(ValueError):
                ov.preview(api, {'paa': device})

    def test_gre_variable_validation(self):
        values = {
            'tunnel_ip': '172.16.101.2/30',
            'spoke_a_tunnel_ip': '172.16.101.1/30',
            'spoke_b_tunnel_ip': '172.16.102.1/30',
        }
        device = copy.deepcopy(DEVICE)
        device['var'] = values
        self.assertEqual(self.load({'paa': device})['paa']['var'], values)
        for field, value in [
            ('tunnel_ip', '172.16.101.2'),
            ('spoke_a_tunnel_ip', '172.16.101.1'),
        ]:
            bad = copy.deepcopy(device)
            bad['var'][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.load({'paa': bad})

    def test_gre_override_apply(self):
        device = copy.deepcopy(DEVICE)
        device['var'] = {'tunnel_ip': '172.16.101.2/30'}
        template = TEMPLATE.replace(
            '</variable>',
            '<entry name="$tunnel_ip"><type><ip-netmask>None</ip-netmask>'
            '</type></entry></variable>',
        )
        api = FakeAPI()
        with patch(__name__ + '.TEMPLATE', template):
            changes = ov.preview(api, self.load({'paa': device}))
            self.assertEqual(ov.apply_changes(api, changes), 1)
            self.assertEqual(ov.preview(api, {'paa': device}), [])

    def test_duplicate_json_keys(self):
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            json.loads('{"a": 1, "a": 2}', object_pairs_hook=ov.unique_object)

    def test_plan_apply_preserves_other_overrides_and_is_idempotent(self):
        api = FakeAPI()
        changes = ov.preview(api, {'paa': DEVICE})
        self.assertEqual(len(changes), 3)
        self.assertEqual(api.writes, [])
        self.assertEqual(ov.apply_changes(api, changes), 3)
        self.assertEqual(ov.preview(api, {'paa': DEVICE}), [])
        self.assertEqual(api.stack.findtext(".//entry[@name='$unrelated']/type/fqdn"), 'keep.example')
        self.assertTrue(all('/devices/entry' in path and '/variable/entry' in path for path, _ in api.writes))

    def test_preflight_rejects_unassigned_device_without_writes(self):
        api = FakeAPI()
        missing = dict(DEVICE, serial='not-assigned')
        with self.assertRaisesRegex(ValueError, 'not assigned'):
            ov.preview(api, {'paa': DEVICE, 'missing': missing})
        self.assertEqual(api.writes, [])

    def test_conflicting_admin_edit_stops_writes(self):
        api = FakeAPI()
        changes = ov.preview(api, {'paa': DEVICE})
        api.stack.find(".//entry[@name='$wan_ip']/type/ip-netmask").text = '10.0.1.4/24'
        with self.assertRaisesRegex(ValueError, 'changed since preview'):
            ov.apply_changes(api, changes)
        self.assertEqual(api.writes, [])

    def test_explicit_null_restores_inheritance(self):
        api = FakeAPI()
        device = dict(DEVICE, var={'wan_ip': None})
        changes = ov.preview(api, self.load({'paa': device}))
        self.assertEqual(ov.apply_changes(api, changes), 1)
        self.assertEqual(ov.preview(api, {'paa': device}), [])
        self.assertIsNotNone(api.stack.find(".//entry[@name='$unrelated']"))

    def test_partial_failure_reports_candidate_state(self):
        api = FakeAPI()
        changes = ov.preview(api, {'paa': DEVICE})
        original = api.set
        def fail_second(path, element):
            if api.writes:
                raise APIError('failure')
            original(path, element)
        api.set = fail_second
        with self.assertRaisesRegex(APIError, 'after 1 verified writes'):
            ov.apply_changes(api, changes)

    def test_file_paths_relative_to_environment(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'device_overrides.json').write_text(json.dumps({'paa': DEVICE}))
            options = ov.parser().parse_args(['plan', '--device', 'paa'])
            api = FakeAPI()
            with patch('sys.stdout', new_callable=io.StringIO):
                self.assertEqual(ov.run(options, root, {}, lambda _: api), 0)
            self.assertEqual(api.writes, [])

    def test_cli_dispatch_does_not_execute_terraform(self):
        from palo_cli import cli
        with patch('sys.argv', ['palo', 'dev', 'overrides', 'plan']), \
             patch.object(cli, 'workspace_root', return_value=Path('/workspace')), \
             patch.object(cli, 'prepare', return_value=(['terraform', '-chdir=/workspace/env/dev', 'overrides'], {'test': 'env'})), \
             patch.object(ov, 'run', return_value=0) as run, \
             patch.object(cli.os, 'execve') as execute:
            self.assertEqual(cli.main(), 0)
            self.assertEqual(run.call_args.args[1], Path('/workspace/env/dev'))
            execute.assert_not_called()

    def test_multiple_devices_keep_separate_values_on_same_stack(self):
        api = FakeAPI()
        second = dict(DEVICE, serial='serial-b', var={'wan_ip': '10.2.1.2/24'})
        devices = {'paa': DEVICE, 'pab': second}
        self.assertEqual(ov.apply_changes(api, ov.preview(api, devices)), 4)
        self.assertEqual(ov.preview(api, devices), [])
        self.assertEqual(api.stack.findtext(".//entry[@name='serial-a']/variable/entry[@name='$wan_ip']/type/ip-netmask"), '10.0.1.2/24')
        self.assertEqual(api.stack.findtext(".//entry[@name='serial-b']/variable/entry[@name='$wan_ip']/type/ip-netmask"), '10.2.1.2/24')

    def test_api_post_and_key_stay_out_of_url(self):
        opener = MagicMock()
        responses = [b'<response status="success"><result><key>secret-key</key></result></response>', b'<response status="success"><result/></response>']
        opener.open.return_value.__enter__.return_value.read.side_effect = responses
        env = {'PANOS_HOSTNAME': 'pano.example', 'PANOS_USERNAME': 'admin', 'PANOS_PASSWORD': 'secret-password'}
        with patch('urllib.request.build_opener', return_value=opener):
            api = PanoramaAPI(env)
            api.get('/config/test')
        first = opener.open.call_args_list[0].args[0]
        second = opener.open.call_args_list[1].args[0]
        self.assertEqual(first.get_method(), 'POST')
        self.assertNotIn('secret', first.full_url)
        self.assertNotIn('secret', second.full_url)
        self.assertEqual(second.get_header('X-pan-key'), 'secret-key')
        self.assertNotIn(b'secret-password', second.data)

    def test_api_errors_do_not_echo_response_secrets(self):
        api = PanoramaAPI.__new__(PanoramaAPI)
        api.url, api.key, api.opener = 'https://pano/api/', None, MagicMock()
        api.opener.open.return_value.__enter__.return_value.read.return_value = b'<response status="error" code="403"><msg>secret-password</msg></response>'
        with self.assertRaises(APIError) as error:
            api.request(type='keygen')
        self.assertNotIn('secret', str(error.exception))
        with self.assertRaises(APIError):
            NoRedirect().redirect_request(None, None, 302, '', {}, 'https://other.example')


if __name__ == '__main__':
    unittest.main()

import contextlib
import io
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import Mock, patch
import xml.etree.ElementTree as ET

from palo_cli import onboard
from palo_cli.panorama_api import APIError


def response(body='', code='19'):
    return ET.fromstring(f'<response status="success" code="{code}"><result>{body}</result></response>')


class OnboardTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.child = {'PANOS_HOSTNAME': '192.0.2.1', 'PANOS_USERNAME': 'admin', 'PANOS_PASSWORD': 'password', 'PANOS_SKIP_VERIFY_CERTIFICATE': 'true'}
        self.panorama = Mock()
        self.firewall = Mock()
        self.devices = {'pa-a': {'api': self.firewall, 'host': '192.0.2.2', 'serial': '001234', 'connected': False, 'registered': False}}
        self.options = onboard.parser().parse_args(['apply', '--auto-approve', '--timeout', '1'])
        def pano_request(**args):
            cmd = ET.fromstring(args['cmd'])
            if cmd.find('authkey/add') is not None:
                return response("Added authkey 'palo-test': '2:registration-secret'")
            if cmd.find('devices/all') is not None:
                return response('<devices><entry name="001234"><connected>yes</connected></entry></devices>')
            return response()
        self.panorama.request.side_effect = pano_request
        self.firewall.request.return_value = response()
        self.output = io.StringIO()

    def execute(self):
        with patch.object(onboard, 'preflight', return_value=(self.panorama, '192.0.2.1', self.devices)), contextlib.redirect_stdout(self.output), contextlib.redirect_stderr(self.output):
            return onboard.run(self.options, self.root, self.child)

    def test_complete_workflow_persists_private_keys_and_configures_firewall(self):
        self.options.connection_check = True
        self.assertEqual(self.execute(), 0)
        path = self.root / 'onboarding.json'
        journal = json.loads(path.read_text())
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        self.assertEqual(next(iter(journal['registration_keys'].values()))['auth_key'], '2:registration-secret')
        self.assertEqual(journal['devices']['pa-a']['stage'], 'connected')
        self.assertEqual(json.loads((self.root / 'serial.json').read_text()), {'pa-a': '001234'})
        self.assertNotIn('registration-secret', self.output.getvalue())
        self.panorama.set.assert_called_once_with(onboard.DEVICES, '<entry name="001234" />')
        self.firewall.set.assert_called_once_with(onboard.SYSTEM + '/panorama', '<local-panorama><panorama-server>192.0.2.1</panorama-server></local-panorama>')
        self.assertEqual(self.firewall.request.call_args_list[0].kwargs, {'type': 'op', 'cmd': '<request><authkey><set>2:registration-secret</set></authkey></request>'})
        add = ET.fromstring(self.panorama.request.call_args_list[0].kwargs['cmd'])
        self.assertEqual(add.findtext('authkey/add/serial/member'), '001234')
        self.assertEqual(add.findtext('authkey/add/devtype'), 'fw')

    def test_default_skips_connection_wait_but_commits(self):
        self.assertFalse(self.options.connection_check)
        with patch.object(onboard, 'connected_serials') as connected:
            self.assertEqual(self.execute(), 0)
            connected.assert_not_called()
        journal = json.loads((self.root / 'onboarding.json').read_text())
        self.assertEqual(journal['devices']['pa-a']['stage'], 'firewall_committed')
        self.assertIn('Connection check skipped', self.output.getvalue())
        for api in [self.panorama, self.firewall]:
            self.assertTrue(any(call.kwargs['type'] == 'commit' for call in api.request.call_args_list))

    def test_connection_check_flag_waits_and_reports_timeout(self):
        self.options = onboard.parser().parse_args(['apply', '--auto-approve', '--connection-check', '--timeout', '1'])
        with patch.object(onboard, 'connected_serials', return_value=set()) as connected, patch.object(onboard.time, 'monotonic', side_effect=[0, 2]):
            self.assertEqual(self.execute(), 1)
            connected.assert_called_once_with(self.panorama)
        self.assertEqual(json.loads((self.root / 'onboarding.json').read_text())['devices']['pa-a']['stage'], 'firewall_committed')

    def test_multiple_devices_share_one_serial_restricted_key(self):
        second = Mock()
        second.request.return_value = response()
        self.devices['pa-b'] = {'api': second, 'host': '192.0.2.3', 'serial': '005678', 'connected': False, 'registered': False}
        self.assertEqual(self.execute(), 0)
        adds = [ET.fromstring(c.kwargs['cmd']) for c in self.panorama.request.call_args_list if '<add>' in c.kwargs.get('cmd', '')]
        self.assertEqual(len(adds), 1)
        self.assertEqual([e.text for e in adds[0].findall('authkey/add/serial/member')], ['001234', '005678'])
        self.assertEqual(adds[0].findtext('authkey/add/count'), '100')
        for api in [self.firewall, second]:
            self.assertEqual(ET.fromstring(api.request.call_args_list[0].kwargs['cmd']).findtext('authkey/set'), '2:registration-secret')
        journal = json.loads((self.root / 'onboarding.json').read_text())
        self.assertTrue(all('auth_key' not in d for d in journal['devices'].values()))
        self.assertEqual(next(iter(journal['registration_keys'].values()))['serials'], ['001234', '005678'])

    def test_small_key_count_reduces_batch_size(self):
        self.options.key_count = 1
        self.devices['pa-b'] = dict(self.devices['pa-a'], serial='005678', host='192.0.2.3')
        self.assertEqual(self.execute(), 0)
        journal = json.loads((self.root / 'onboarding.json').read_text())
        self.assertEqual(len(journal['registration_keys']), 2)

    def test_more_than_100_devices_receive_bounded_batch_keys(self):
        self.devices = {
            f'pa-{i:03}': {'api': Mock(request=Mock(return_value=response())), 'host': f'192.0.2.{i + 1}',
                          'serial': f'{i:06}', 'connected': False, 'registered': False}
            for i in range(121)
        }
        self.assertEqual(self.execute(), 0)
        journal = json.loads((self.root / 'onboarding.json').read_text())
        entries = list(journal['registration_keys'].values())
        self.assertEqual(sorted(len(e['serials']) for e in entries), [21, 50, 50])
        adds = [c for c in self.panorama.request.call_args_list if '<add>' in c.kwargs.get('cmd', '')]
        self.assertEqual(len(adds), 3)
        for name, d in self.devices.items():
            self.assertIn(d['serial'], journal['registration_keys'][journal['devices'][name]['key_name']]['serials'])
        # Simulate a partial run with alternating devices connected. Reuse all three keys.
        for i, d in enumerate(self.devices.values()):
            d['connected'] = i % 2 == 0
        self.panorama.reset_mock()
        self.assertEqual(self.execute(), 0)
        self.assertFalse(any('<add>' in c.kwargs.get('cmd', '') for c in self.panorama.request.call_args_list))

    def test_legacy_single_key_record_is_reused(self):
        self.assertEqual(self.execute(), 0)
        path = self.root / 'onboarding.json'
        journal = json.loads(path.read_text())
        journal['registration_key'] = next(iter(journal.pop('registration_keys').values()))
        path.write_text(json.dumps(journal))
        self.panorama.reset_mock()
        self.assertEqual(self.execute(), 0)
        self.assertFalse(any('<add>' in c.kwargs.get('cmd', '') for c in self.panorama.request.call_args_list))
        self.assertIn('registration_keys', json.loads(path.read_text()))

    def test_plan_no_files_or_writes(self):
        self.options.operation = 'plan'
        self.assertEqual(self.execute(), 0)
        self.assertEqual(list(self.root.iterdir()), [])
        self.panorama.request.assert_not_called()
        self.panorama.set.assert_not_called()
        self.firewall.request.assert_not_called()

    def test_connected_devices_skipped(self):
        self.devices['pa-a']['connected'] = True
        self.assertEqual(self.execute(), 0)
        self.panorama.request.assert_not_called()
        self.firewall.request.assert_not_called()

    def test_cancel_no_files_or_writes(self):
        self.options.auto_approve = False
        with patch('builtins.input', return_value='no'):
            self.assertEqual(self.execute(), 0)
        self.assertEqual(list(self.root.iterdir()), [])
        self.panorama.request.assert_not_called()

    def test_panorama_failure_stops_before_firewall(self):
        self.panorama.set.side_effect = APIError('failure including sensitive server content')
        self.assertEqual(self.execute(), 1)
        self.firewall.request.assert_not_called()
        self.assertNotIn('sensitive', self.output.getvalue())
        self.assertIn('auth_key', next(iter(json.loads((self.root / 'onboarding.json').read_text())['registration_keys'].values())))

    def test_retry_uses_saved_unexpired_key(self):
        self.assertEqual(self.execute(), 0)
        self.panorama.reset_mock()
        self.devices['pa-a']['registered'] = True
        self.assertEqual(self.execute(), 0)
        self.assertFalse(any('<add>' in call.kwargs.get('cmd', '') for call in self.panorama.request.call_args_list))
        self.panorama.set.assert_not_called()

    def test_commit_failure_and_timeout_preserve_job(self):
        path = self.root / 'onboarding.json'
        for outcome in ['FAIL', 'PEND']:
            journal = {'jobs': {}}
            api = Mock()
            api.request.side_effect = [response('<job>42</job>'), response(f'<job><status>{"FIN" if outcome == "FAIL" else "ACT"}</status><result>{outcome}</result></job>')]
            with patch.object(onboard.time, 'monotonic', side_effect=[0, 2]), contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaises(APIError):
                    onboard.commit(api, 'Panorama', journal, path, 1)
            self.assertEqual(json.loads(path.read_text())['jobs']['Panorama'], '42')

    def test_key_xml_escaping_and_response_formats(self):
        self.assertEqual(ET.fromstring(onboard.xml('request', {'authkey/set': 'a<&b'})).findtext('authkey/set'), 'a<&b')
        for body in ['<authkey>secret</authkey>', '<key>secret</key>', 'Name : key\nKey : secret\nCount : 5']:
            self.assertEqual(onboard.extract_key(response(body)), 'secret')
        with self.assertRaises(APIError):
            onboard.extract_key(response('unexpected secret not printed'))

    def test_preflight_rejects_other_panorama_without_writes(self):
        (self.root / 'palo.json').write_text(json.dumps({'hostname': '192.0.2.1', 'device': {'pa-a': '192.0.2.2'}}))
        self.panorama.request.return_value = response('<devices/>')
        self.panorama.request.side_effect = None
        self.panorama.get.return_value = response('<devices/>')
        self.firewall.request.side_effect = [response('<system><serial>001234</serial></system>'), response('<system><panorama><local-panorama><panorama-server>192.0.2.99</panorama-server></local-panorama></panorama></system>')]
        with patch.object(onboard, 'PanoramaAPI', side_effect=[self.panorama, self.firewall]), contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaisesRegex(ValueError, 'another Panorama'):
                onboard.preflight(self.root, self.child)
        self.panorama.set.assert_not_called()
        self.firewall.set.assert_not_called()

    def test_help_skips_keyring(self):
        from palo_cli import cli
        with patch.object(cli.sys, 'argv', ['palo', 'lab', 'onboard', '--help']), patch.object(cli, 'workspace_root', return_value=self.root), patch.object(cli, 'prepare') as prepare, contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit):
                cli.main()
            prepare.assert_not_called()


if __name__ == '__main__':
    unittest.main()

import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
import xml.etree.ElementTree as ET

from palo_cli import cli, ha
from palo_cli.panorama_api import APIError


def status(serial, peer_serial, state, peer_state):
    root = ET.Element('response', status='success')
    result = ET.SubElement(root, 'result')
    ET.SubElement(result, 'enabled').text = 'yes'
    for tag, identity, role in [('local-info', serial, state),
                                ('peer-info', peer_serial, peer_state)]:
        info = ET.SubElement(result, tag)
        ET.SubElement(info, 'serial-num').text = identity
        ET.SubElement(info, 'state').text = role
    return root


class HATest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.env = self.root / 'env/dev'
        self.env.mkdir(parents=True)
        self.config = {
            'hostname': 'primary.example.com',
            'secondary_panorama_ip': '192.0.2.2',
            'keyring_service': 'test', 'keyring_username': 'admin',
            'ha_auto_detect': True,
        }
        self.backend = Mock()
        self.backend.get_password.return_value = 'secret'
        self.first = Mock()
        self.second = Mock()
        self.first.request.return_value = status('A', 'B', 'active', 'passive')
        self.second.request.return_value = status('B', 'A', 'passive', 'active')

    def prepare(self, command='plan'):
        (self.env / 'palo.json').write_text(json.dumps(self.config))
        with contextlib.redirect_stderr(io.StringIO()):
            return cli.prepare(['dev', command], self.root, {}, self.backend)

    def test_primary_or_secondary_active_selects_endpoint_only(self):
        for active in [0, 1]:
            roles = (['active', 'passive'] if active == 0
                     else ['passive', 'active'])
            self.first.request.return_value = status('A', 'B', *roles)
            self.second.request.return_value = status('B', 'A', *roles[::-1])
            with patch.object(ha, 'PanoramaAPI', side_effect=[
                self.first, self.second,
            ]) as factory:
                command, child = self.prepare()
            expected = (self.config['hostname'] if active == 0 else
                        self.config['secondary_panorama_ip'])
            self.assertEqual(child['PANOS_HOSTNAME'], expected)
            self.assertEqual(command[1], f'-chdir={self.env.resolve()}')
            self.assertEqual(factory.call_count, 2)
            self.first.request.assert_called_with(type='op', cmd=ha.HA_STATE)
            self.assertEqual(json.loads((self.env / 'palo.json').read_text()),
                             self.config)
            self.assertEqual(child['PANOS_PASSWORD'], 'secret')

    def test_reject_ambiguous_states_and_unrelated_peers(self):
        invalid = [
            status('B', 'A', 'active', 'active'),
            status('B', 'A', 'passive', 'passive'),
            status('B', 'A', 'initial', 'active'),
            status('C', 'D', 'passive', 'active'),
            status('A', 'A', 'passive', 'active'),
            ET.fromstring('<response><result><enabled>no</enabled>'
                          '</result></response>'),
            ET.fromstring('<response><result><enabled>yes</enabled>'
                          '</result></response>'),
        ]
        for reply in invalid:
            self.second.request.return_value = reply
            with patch.object(ha, 'PanoramaAPI', side_effect=[
                self.first, self.second,
            ]), self.assertRaises(ValueError):
                self.prepare()

    def test_unreachable_peer_stops_without_leaking_response(self):
        for failure in [0, 1]:
            peers = [self.first, self.second]
            peers[failure] = APIError('secret server response')
            with patch.object(ha, 'PanoramaAPI', side_effect=peers):
                with self.assertRaisesRegex(ValueError, 'Both peers') as error:
                    self.prepare()
            self.assertNotIn('secret', str(error.exception))

    def test_disabled_offline_and_serials_do_not_probe(self):
        for command in [*cli.OFFLINE, 'serials']:
            with patch.object(ha, 'PanoramaAPI') as api:
                self.prepare(command)
                api.assert_not_called()
        self.config['ha_auto_detect'] = False
        with patch.object(ha, 'PanoramaAPI') as api:
            _, child = self.prepare()
            api.assert_not_called()
            self.assertEqual(child['PANOS_HOSTNAME'], self.config['hostname'])

    def test_onboarding_refuses_active_secondary(self):
        self.first.request.return_value = status('A', 'B', 'passive', 'active')
        self.second.request.return_value = status('B', 'A', 'active', 'passive')
        with patch.object(ha, 'PanoramaAPI', side_effect=[
            self.first, self.second,
        ]), self.assertRaisesRegex(ValueError, 'configured primary'):
            self.prepare('onboard')

    def test_onboarding_keeps_primary_endpoint(self):
        with patch.object(ha, 'PanoramaAPI', side_effect=[
            self.first, self.second,
        ]):
            _, child = self.prepare('onboard')
        self.assertEqual(child['PANOS_HOSTNAME'], self.config['hostname'])

    def test_invalid_configuration(self):
        self.config['ha_auto_detect'] = 'true'
        with self.assertRaisesRegex(ValueError, 'JSON boolean'):
            self.prepare()
        self.backend.get_password.assert_not_called()
        self.config['ha_auto_detect'] = True
        for value in [None, '', 'bad', 123]:
            self.config['secondary_panorama_ip'] = value
            with patch.object(ha, 'PanoramaAPI') as api:
                with self.assertRaisesRegex(
                    ValueError, 'secondary_panorama_ip'
                ):
                    self.prepare()
                api.assert_not_called()


if __name__ == '__main__':
    unittest.main()

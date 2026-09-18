import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
import xml.etree.ElementTree as ET

from palo_cli import serials
from palo_cli.panorama_api import APIError


class SerialsTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.config({'pa-a': '192.0.2.10', 'pa-b': '192.0.2.11'})
        self.child = {'PANOS_HOSTNAME': 'panorama.example.com', 'PANOS_USERNAME': 'admin', 'PANOS_PASSWORD': 'secret', 'PANOS_SKIP_VERIFY_CERTIFICATE': 'true'}

    def config(self, devices):
        (self.root / 'palo.json').write_text(json.dumps({'device': devices}))

    def api(self, serial):
        return Mock(request=Mock(return_value=ET.fromstring(f'<response status="success"><result><system><serial>{serial}</serial></system></result></response>')))

    def execute(self, factory):
        with patch.object(serials, 'PanoramaAPI', factory), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return serials.run(self.root, self.child)

    def test_all_hosts_save_serial_strings_without_credentials(self):
        a, b = self.api('00123'), self.api('00456')
        factory = Mock(side_effect=[a, b])
        self.assertEqual(self.execute(factory), 0)
        self.assertEqual(json.loads((self.root / 'serial.json').read_text()), {'pa-a': '00123', 'pa-b': '00456'})
        self.assertEqual([c.args[0]['PANOS_HOSTNAME'] for c in factory.call_args_list], ['192.0.2.10', '192.0.2.11'])
        self.assertEqual(factory.call_args_list[0].args[0]['PANOS_PASSWORD'], 'secret')
        self.assertEqual(factory.call_args_list[0].args[0]['PANOS_SKIP_VERIFY_CERTIFICATE'], 'true')
        self.assertEqual(self.child['PANOS_HOSTNAME'], 'panorama.example.com')
        a.request.assert_called_once_with(type='op', cmd='<show><system><info></info></system></show>')

    def test_failed_host_preserves_file_and_queries_remaining_hosts(self):
        output = self.root / 'serial.json'
        output.write_text('{"old":"00001"}\n')
        factory = Mock(side_effect=[APIError('auth failed'), self.api('00456')])
        self.assertEqual(self.execute(factory), 1)
        self.assertEqual(factory.call_count, 2)
        self.assertEqual(output.read_text(), '{"old":"00001"}\n')

    def test_invalid_or_missing_serial_never_writes(self):
        for value in ['', 'unknown', 'None']:
            factory = Mock(return_value=self.api(value))
            self.assertEqual(self.execute(factory), 1)
            self.assertFalse((self.root / 'serial.json').exists())

    def test_diagnostics_identify_host_and_preserve_file(self):
        saved = self.root / 'serial.json'
        saved.write_text('{"old":"00001"}\n')
        detail = '192.0.2.10: authentication (keygen): HTTP 503: management service unavailable or restarting'
        factory = Mock(side_effect=[APIError('raw-secret', diagnostic=detail), self.api('00456')])
        errors = io.StringIO()
        with patch.object(serials, 'PanoramaAPI', factory), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(errors):
            self.assertEqual(serials.run(self.root, self.child), 1)
        self.assertIn('pa-a (192.0.2.10)', errors.getvalue())
        self.assertIn(detail, errors.getvalue())
        self.assertNotIn('raw-secret', errors.getvalue())
        self.assertEqual(factory.call_count, 2)
        self.assertEqual(saved.read_text(), '{"old":"00001"}\n')

    def test_missing_serial_has_specific_diagnostic(self):
        errors = io.StringIO()
        with patch.object(serials, 'PanoramaAPI', return_value=self.api('')), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(errors):
            self.assertEqual(serials.run(self.root, self.child), 1)
        self.assertIn('show system info: response contained no valid serial number', errors.getvalue())

    def test_untrusted_error_text_is_not_printed(self):
        errors = io.StringIO()
        with patch.object(serials, 'PanoramaAPI', side_effect=APIError('raw-secret')), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(errors):
            self.assertEqual(serials.run(self.root, self.child), 1)
        self.assertNotIn('raw-secret', errors.getvalue())
        self.assertIn('API request failed', errors.getvalue())

    def test_invalid_inventory_rejected_before_connection(self):
        for devices in [{}, [], {'pa-a': 'https://192.0.2.10'}, {'pa-a': 123}, {'bad name': '192.0.2.10'}]:
            self.config(devices)
            factory = Mock()
            self.assertEqual(self.execute(factory), 1)
            factory.assert_not_called()

    def test_duplicate_keys_rejected_and_ipv6_supported(self):
        (self.root / 'palo.json').write_text('{"device":{"pa-a":"192.0.2.10","pa-a":"192.0.2.11"}}')
        with self.assertRaises(ValueError):
            serials.load_devices(self.root)
        self.config({'pa-a': '2001:db8::1'})
        self.assertEqual(serials.load_devices(self.root), {'pa-a': '[2001:db8::1]'})

    def test_help_does_not_read_keyring(self):
        from palo_cli import cli
        with patch.object(cli.sys, 'argv', ['palo', 'lab', 'serials', '--help']), patch.object(cli, 'workspace_root', return_value=self.root), patch.object(cli, 'prepare') as prepare, contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as result:
                cli.main()
            self.assertEqual(result.exception.code, 0)
            prepare.assert_not_called()


if __name__ == '__main__':
    unittest.main()

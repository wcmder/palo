import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock

from palo_cli import cli as palo


class LauncherTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name in ['dev', 'dev2']:
            p = self.root / 'env' / name
            p.mkdir(parents=True)
            (p / 'palo.json').write_text(json.dumps({'hostname': name+'.example.com', 'keyring_service': 'panos_'+name, 'keyring_username': 'admin'}))
        self.backend = Mock()
        self.backend.get_password.return_value = 'test-secret'

    def test_environment_selection_and_credentials(self):
        parent = {'PATH': '/bin', 'PANOS_API_KEY': 'old', 'PANOS_TARGET': 'old', 'PANOS_HOSTNAME': 'old'}
        for name in ['dev', 'dev2']:
            cmd, child = palo.prepare([name, 'plan', '-out=review.tfplan'], self.root, parent, self.backend)
            self.assertEqual(cmd, ['terraform', '-chdir='+str((self.root/'env'/name).resolve()), 'plan', '-out=review.tfplan'])
            self.assertEqual(child['PANOS_HOSTNAME'], name+'.example.com')
            self.assertEqual(child['PANOS_PASSWORD'], 'test-secret')
            self.assertNotIn('PANOS_API_KEY', child)
            self.assertNotIn('PANOS_TARGET', child)
            self.assertNotIn('test-secret', ' '.join(cmd))
            self.backend.get_password.assert_called_with('panos_'+name, 'admin')
        self.assertEqual(parent['PANOS_HOSTNAME'], 'old')
        self.assertNotIn('PANOS_PASSWORD', parent)

    def test_certificate_verification_option(self):
        config_path = self.root / 'env/dev/palo.json'
        config = json.loads(config_path.read_text())
        for setting in [None, False, True]:
            if setting is None:
                config.pop('skip_verify_certificate', None)
            else:
                config['skip_verify_certificate'] = setting
            config_path.write_text(json.dumps(config))
            parent = {'PANOS_SKIP_VERIFY_CERTIFICATE': 'true'}
            _, child = palo.prepare(['dev', 'plan'], self.root, parent, self.backend)
            self.assertEqual(child['PANOS_SKIP_VERIFY_CERTIFICATE'], 'true' if setting else 'false')
            self.assertEqual(parent['PANOS_SKIP_VERIFY_CERTIFICATE'], 'true')

    def test_reject_non_boolean_certificate_option(self):
        config_path = self.root / 'env/dev/palo.json'
        config = json.loads(config_path.read_text())
        for setting in ['false', 'true', 0, 1, None]:
            config['skip_verify_certificate'] = setting
            config_path.write_text(json.dumps(config))
            with self.subTest(setting=setting), self.assertRaisesRegex(ValueError, 'JSON boolean'):
                palo.prepare(['dev', 'plan'], self.root, {}, self.backend)
        self.backend.get_password.assert_not_called()

    def test_offline_needs_no_configuration_or_keyring(self):
        (self.root/'env/dev/palo.json').unlink()
        for command in palo.OFFLINE:
            palo.prepare(['dev', command], self.root, {}, self.backend)
        self.backend.get_password.assert_not_called()

    def test_reject_invalid_environment_and_directory_override(self):
        for args in [['../dev', 'plan'], ['missing', 'plan'], ['dev', '-chdir=/tmp'], ['dev', 'plan', '-chdir=/tmp']]:
            with self.subTest(args=args), self.assertRaises(ValueError):
                palo.prepare(args, self.root, {}, self.backend)

    def test_missing_hostname_does_not_read_keyring(self):
        (self.root/'env/dev/palo.json').write_text('{"hostname":""}')
        with self.assertRaisesRegex(ValueError, 'Set hostname'):
            palo.prepare(['dev', 'plan'], self.root, {}, self.backend)
        self.backend.get_password.assert_not_called()

    def test_symlink_cannot_escape_environment_directory(self):
        (self.root/'env/escape').symlink_to(self.root, target_is_directory=True)
        with self.assertRaises(ValueError):
            palo.prepare(['escape', 'plan'], self.root, {}, self.backend)


if __name__ == '__main__':
    unittest.main()

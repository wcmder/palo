import contextlib
import io
import json
import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch

from palo_cli import credentials as get_creds


class CredentialsTest(unittest.TestCase):
    def test_explicit_account(self):
        backend = Mock()
        backend.get_password.return_value = 'a"b\\c\n'
        result = get_creds.resolve({"service": "test", "username": "admin"}, backend)
        self.assertEqual(json.loads(json.dumps(result)), {"username": "admin", "password": 'a"b\\c\n'})
        backend.get_password.assert_called_once_with("test", "admin")

    def test_discover_account(self):
        backend = Mock()
        backend.get_credential.return_value = SimpleNamespace(username="admin", password="test")
        self.assertEqual(get_creds.resolve({"service": "test"}, backend)["username"], "admin")
        backend.get_credential.assert_called_once_with("test", None)

    def test_cisco_multi_secret(self):
        backend = Mock()
        backend.get_password.return_value = "test"
        self.assertEqual(get_creds.resolve({"pano": json.dumps({"service": "test", "username": "admin"})}, backend), {"pano": "test"})

    def test_missing_and_invalid(self):
        backend = Mock()
        backend.get_credential.return_value = None
        for query in [{}, [], {"service": ""}, {"service": "test", "username": 1}, {"service": "test"}]:
            with self.subTest(query=query), self.assertRaises(get_creds.CredentialError):
                get_creds.resolve(query, backend)

    def test_backend_failure_does_not_leak(self):
        backend = Mock()
        backend.get_credential.side_effect = RuntimeError("secret-value")
        out, err = io.StringIO(), io.StringIO()
        with patch.dict("sys.modules", {"keyring": backend}), patch("sys.stdin", io.StringIO('{"service":"test"}')), contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            self.assertEqual(get_creds.main(), 1)
        self.assertEqual(out.getvalue(), "")
        self.assertNotIn("secret-value", err.getvalue())


if __name__ == "__main__":
    unittest.main()

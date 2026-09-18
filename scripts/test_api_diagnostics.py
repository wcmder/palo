import contextlib
import io
import json
from pathlib import Path
import socket
import ssl
import tempfile
import unittest
from unittest.mock import MagicMock, Mock, patch
import urllib.error
import xml.etree.ElementTree as ET

from palo_cli.panorama_api import APIError, PanoramaAPI
from palo_cli import onboard


class DiagnosticsTest(unittest.TestCase):
    def setUp(self):
        self.api = PanoramaAPI.__new__(PanoramaAPI)
        self.api.url = 'https://192.0.2.2/api/'
        self.api.key = 'secret-api-token'
        self.api.secrets = ['secret-password', 'admin']
        self.api.opener = MagicMock()

    def request_error(self):
        with self.assertRaises(APIError) as result:
            self.api.request(type='op', cmd='<show><system><info/></system></show>')
        error = result.exception
        self.assertEqual(error.diagnostic, str(error))
        self.assertIn('192.0.2.2: show system info:', str(error))
        return str(error)

    def test_transport_categories_without_raw_exception_text(self):
        cases = [
            (TimeoutError('secret-password'), 'timed out'),
            (ConnectionRefusedError('secret-password'), 'connection refused'),
            (ConnectionResetError('secret-password'), 'connection reset'),
            (socket.gaierror('secret-password'), 'DNS lookup failed'),
            (ssl.SSLCertVerificationError('secret-password'), 'certificate verification failed'),
        ]
        for cause, expected in cases:
            with self.subTest(expected=expected):
                self.api.opener.open.side_effect = urllib.error.URLError(cause)
                message = self.request_error()
                self.assertIn(expected, message)
                self.assertNotIn('secret-password', message)

    def test_http_busy_and_auth_errors(self):
        for code, expected in [(503, 'unavailable or restarting'), (401, 'authentication'), (403, 'access denied')]:
            self.api.opener.open.side_effect = urllib.error.HTTPError(self.api.url, code, 'secret-password', {}, None)
            message = self.request_error()
            self.assertIn(f'HTTP {code}', message)
            self.assertIn(expected, message)
            self.assertNotIn('secret-password', message)

    def test_pan_os_message_and_known_secret_redaction(self):
        self.api.opener.open.return_value.__enter__.return_value.read.return_value = b'<response status="error" code="7"><msg><line>Management server busy: secret-password secret-api-token</line></msg></response>'
        message = self.request_error()
        self.assertIn('PAN-OS error 7', message)
        self.assertIn('Management server busy', message)
        self.assertNotIn('secret', message)

    def test_invalid_xml_does_not_echo_body(self):
        self.api.opener.open.return_value.__enter__.return_value.read.return_value = b'secret-password'
        self.assertIn('invalid XML', self.request_error())

    def test_registration_key_errors_suppress_unknown_key_material(self):
        self.api.opener.open.return_value.__enter__.return_value.read.return_value = b'<response status="error" code="1"><msg>new registration token VERY_PRIVATE_UNKNOWN_VALUE</msg></response>'
        with self.assertRaises(APIError) as result:
            self.api.request(type='op', cmd='<request><authkey><add/></authkey></request>')
        self.assertNotIn('VERY_PRIVATE', str(result.exception))
        self.assertIn('registration-key operation', str(result.exception))

    def test_preflight_identifies_failing_firewall_and_reports_no_writes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'palo.json').write_text(json.dumps({'hostname': '192.0.2.1', 'device': {'pa-b': '192.0.2.2'}}))
            panorama = Mock()
            panorama.request.return_value = ET.fromstring('<response><result><devices/></result></response>')
            panorama.get.return_value = panorama.request.return_value
            diagnostic = '192.0.2.2: authentication (keygen): HTTP 503: management service unavailable or restarting'
            output = io.StringIO()
            with patch.object(onboard, 'PanoramaAPI', side_effect=[panorama, APIError(diagnostic, diagnostic=diagnostic)]), contextlib.redirect_stdout(output), contextlib.redirect_stderr(output):
                result = onboard.run(onboard.parser().parse_args(['plan']), root, {'PANOS_HOSTNAME': '192.0.2.1'})
            self.assertEqual(result, 1)
            self.assertIn('pa-b (192.0.2.2)', output.getvalue())
            self.assertIn('HTTP 503', output.getvalue())
            self.assertIn('No onboarding writes or commits', output.getvalue())
            panorama.set.assert_not_called()
            self.assertFalse((root / 'onboarding.json').exists())

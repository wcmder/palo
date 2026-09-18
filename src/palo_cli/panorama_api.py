"""Small HTTPS XML API client. Credentials and keys remain in process memory."""
import re
import socket
import ssl
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET


class APIError(ValueError):
    def __init__(self, message, *, diagnostic=None):
        super().__init__(message)
        self.diagnostic = diagnostic



class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise APIError("Panorama redirected the API request; check the configured hostname.")


class PanoramaAPI:
    def __init__(self, environ):
        host = environ['PANOS_HOSTNAME']
        self.secrets = [environ.get('PANOS_PASSWORD', ''), environ.get('PANOS_USERNAME', '')]
        parsed = urllib.parse.urlsplit('https://' + host)
        if not parsed.hostname or parsed.username or parsed.password or parsed.path or parsed.query or parsed.fragment:
            raise APIError('PANOS_HOSTNAME must be a hostname/IP with an optional port, without a URL path.')
        self.url = 'https://' + host + '/api/'
        context = ssl.create_default_context()
        if environ.get('PANOS_SKIP_VERIFY_CERTIFICATE') == 'true':
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
        self.opener = urllib.request.build_opener(
            urllib.request.ProxyHandler({}), urllib.request.HTTPSHandler(context=context), NoRedirect())
        self.key = None
        result = self.request(type='keygen', user=environ['PANOS_USERNAME'], password=environ['PANOS_PASSWORD'])
        self.key = result.findtext('./result/key')
        if not self.key:
            raise APIError('Panorama did not return an API key.')

    def operation(self, params):
        kind = params.get('type')
        if kind == 'keygen':
            return 'authentication (keygen)', True
        if kind == 'commit':
            return 'commit', False
        if kind == 'config':
            action = params.get('action')
            return 'configuration ' + (action if action in {'get', 'show', 'set', 'edit', 'delete'} else 'request'), False
        command = params.get('cmd', '')
        if '<authkey>' in command:
            return 'registration-key operation', True
        if '<system>' in command and '<info' in command:
            return 'show system info', False
        if '<jobs>' in command:
            return 'show commit job', False
        if '<devices>' in command:
            return 'show managed devices', False
        return 'operational request', False

    def safe_message(self, root, params, sensitive):
        text = ' '.join(' '.join(node.itertext()) for node in root.findall('./msg'))
        if not text:
            text = ' '.join(' '.join(node.itertext()) for node in root.findall('./result/msg'))
        if sensitive:
            # Authentication/key operations can echo secrets unknown to the client.
            for phrase, reason in [('invalid credential', 'invalid credentials'),
                                   ('invalid username', 'invalid username or password'),
                                   ('invalid password', 'invalid username or password'),
                                   ('temporarily unavailable', 'service temporarily unavailable'),
                                   ('not ready', 'management service not ready'),
                                   ('busy', 'management service busy'),
                                   ('unauthorized', 'authentication or API access denied'),
                                   ('unexpected here', 'invalid command syntax: an XML element is unexpected here'),
                                   ('invalid command', 'invalid operational command syntax'),
                                   ('invalid serial', 'invalid serial number or serial-list format'),
                                   ('can be at most 31 characters', 'registration-key name exceeds the 31-character limit'),
                                   ('too long', 'a command parameter exceeds its allowed length'),
                                   ('failed to update db', 'failed to update the registration-key database'),
                                   ('does not exist', 'the requested registration key does not exist')]:
                if phrase in text.lower():
                    return reason
            return 'Check credentials, API permissions and management-service readiness.'
        secrets = list(getattr(self, 'secrets', [])) + [self.key, params.get('password'), params.get('key')]
        for secret in sorted((x for x in secrets if x), key=len, reverse=True):
            for value in {secret, urllib.parse.quote(secret, safe=''), urllib.parse.quote_plus(secret)}:
                text = text.replace(value, '[REDACTED]')
        # Suppress messages mentioning key material rather than risking partial redaction.
        if re.search(r'password|auth.?key|api.?key|private.?key|X-PAN-KEY|BEGIN .*KEY', text, re.I):
            return 'Server detail omitted because it contains credential/key fields.'
        return re.sub(r'\s+', ' ', text).strip()[:500]

    def request(self, **params):
        operation, sensitive = self.operation(params)
        host = urllib.parse.urlsplit(self.url).hostname or 'configured host'

        def failure(reason):
            detail = f'{host}: {operation}: {reason}'
            return APIError(detail, diagnostic=detail)

        headers = {'Content-Type': 'application/x-www-form-urlencoded'}
        if self.key:
            headers['X-PAN-KEY'] = self.key
        req = urllib.request.Request(self.url, data=urllib.parse.urlencode(params).encode(), headers=headers, method='POST')
        try:
            with self.opener.open(req, timeout=30) as response:
                data = response.read()
            root = ET.fromstring(data)
        except urllib.error.HTTPError as exc:
            reasons = {401: 'authentication required or rejected', 403: 'access denied',
                       429: 'too many requests', 502: 'gateway error',
                       503: 'management service unavailable or restarting', 504: 'gateway timeout'}
            exc.close()
            raise failure(f'HTTP {exc.code}: {reasons.get(exc.code, "HTTP request failed")}') from None
        except (urllib.error.URLError, OSError) as exc:
            reason = exc.reason if isinstance(exc, urllib.error.URLError) else exc
            if isinstance(reason, ssl.SSLCertVerificationError):
                detail = 'TLS certificate verification failed; check the certificate or skip_verify_certificate setting.'
            elif isinstance(reason, ssl.SSLError):
                detail = 'TLS handshake failed.'
            elif isinstance(reason, (TimeoutError, socket.timeout)):
                detail = 'request timed out (30-second timeout); the management service may be restarting or unreachable.'
            elif isinstance(reason, socket.gaierror):
                detail = 'DNS lookup failed.'
            elif isinstance(reason, ConnectionRefusedError):
                detail = 'connection refused; HTTPS may not be ready.'
            elif isinstance(reason, (ConnectionResetError, ConnectionAbortedError)):
                detail = 'connection reset or closed; the management service may be restarting.'
            else:
                detail = 'network connection failed; check routing and HTTPS service availability.'
            raise failure(detail) from None
        except ET.ParseError:
            raise failure('server returned invalid XML; the management API may not be ready.') from None
        except APIError:
            raise failure('HTTP redirect refused; check the configured host.') from None
        if root.tag != 'response':
            raise failure('unexpected XML response; expected a PAN-OS API response.')
        if root.get('status') != 'success':
            code = root.get('code', '')
            code = code if code.isdigit() else 'unknown'
            message = self.safe_message(root, params, sensitive)
            raise failure(f'PAN-OS error {code}: {message or "Request rejected."}')
        return root

    def get(self, xpath):
        return self.request(type='config', action='get', xpath=xpath)

    def set(self, xpath, element):
        return self.request(type='config', action='set', xpath=xpath, element=element)

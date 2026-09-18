"""Small HTTPS XML API client. Credentials and keys remain in process memory."""
import ssl
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET


class APIError(ValueError):
    pass


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise APIError("Panorama redirected the API request; check the configured hostname.")


class PanoramaAPI:
    def __init__(self, environ):
        host = environ['PANOS_HOSTNAME']
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

    def request(self, **params):
        headers = {'Content-Type': 'application/x-www-form-urlencoded'}
        if self.key:
            headers['X-PAN-KEY'] = self.key
        req = urllib.request.Request(self.url, data=urllib.parse.urlencode(params).encode(), headers=headers, method='POST')
        try:
            with self.opener.open(req, timeout=30) as response:
                data = response.read()
            root = ET.fromstring(data)
        except (urllib.error.URLError, OSError, ET.ParseError):
            # Do not echo server responses, headers or request parameters: they may contain secrets.
            raise APIError('Panorama API transport/XML error. Check connectivity, TLS settings and API access; preview again before retrying writes.') from None
        if root.tag != 'response' or root.get('status') != 'success':
            raise APIError('Panorama rejected the API request (code %s). Check API permissions and the target configuration.' % root.get('code', 'unknown'))
        return root

    def get(self, xpath):
        return self.request(type='config', action='get', xpath=xpath)

    def set(self, xpath, element):
        return self.request(type='config', action='set', xpath=xpath, element=element)

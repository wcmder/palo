"""Select one verified Panorama HA peer for the lifetime of a command."""
import ipaddress
import sys

from .panorama_api import APIError, PanoramaAPI


HA_STATE = '<show><high-availability><state/></high-availability></show>'


def peer_state(host, child):
    try:
        api = PanoramaAPI(dict(child, PANOS_HOSTNAME=host))
        response = api.request(type='op', cmd=HA_STATE)
    except APIError:
        # Do not expose authentication replies or credentials in exceptions.
        raise ValueError(
            f'HA discovery failed for {host}; check connectivity, TLS and API '
            'permissions. Both peers must be reachable.'
        ) from None
    if response.findtext('./result/enabled') != 'yes':
        raise ValueError(f'HA is disabled or unrecognized on {host}.')
    result = response.find('result')
    fields = {
        'state': 'local-info/state',
        'serial': 'local-info/serial-num',
        'peer_state': 'peer-info/state',
        'peer_serial': 'peer-info/serial-num',
    }
    status = {key: (result.findtext(path) or '').strip()
              for key, path in fields.items()}
    if not all(status.values()):
        raise ValueError(f'Incomplete Panorama HA status from {host}.')
    return status


def select_active(config, child, command):
    """Verify reciprocal identities and state; never retry writes on a peer."""
    secondary = config.get('secondary_panorama_ip')
    try:
        if not isinstance(secondary, str):
            raise ValueError()
        secondary = str(ipaddress.ip_address(secondary))
    except ValueError:
        raise ValueError(
            'ha_auto_detect requires a valid secondary_panorama_ip.'
        ) from None
    primary = config['hostname']
    if primary == secondary:
        raise ValueError('HA discovery requires two different endpoints.')
    first = peer_state(primary, child)
    second = peer_state(secondary, child)
    if (first['serial'] == second['serial'] or
            first['peer_serial'] != second['serial'] or
            second['peer_serial'] != first['serial']):
        raise ValueError('Configured Panorama endpoints are not one HA pair.')
    if (first['peer_state'] != second['state'] or
            second['peer_state'] != first['state'] or
            {first['state'], second['state']} != {'active', 'passive'}):
        raise ValueError(
            'Panorama HA state is ambiguous or inconsistent; '
            'expected one active and one passive peer. Retry after HA settles.'
        )
    selected = primary if first['state'] == 'active' else secondary
    if command == 'onboard' and selected != primary:
        raise ValueError(
            'Onboarding requires the configured primary Panorama to be active. '
            'Restore that role before onboarding; '
            'do not swap manager addresses.'
        )
    print(f'[palo] Selected active Panorama: {selected}', file=sys.stderr)
    return selected

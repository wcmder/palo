"""Discover firewall serial numbers using read-only system information queries."""
import argparse
import ipaddress
import json
import os
import re
import sys
import tempfile
from pathlib import Path

from .panorama_api import APIError, PanoramaAPI


def parser():
    return argparse.ArgumentParser(prog='palo <environment> serials', description='Read device IPs from palo.json and write hostname-to-serial mappings to serial.json.')


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate key in palo.json.')
        result[key] = value
    return result


def load_devices(root):
    try:
        config = json.loads((root / 'palo.json').read_text(), object_pairs_hook=unique_object)
    except (OSError, ValueError):
        raise ValueError('palo.json must be readable, valid JSON without duplicate keys.') from None
    devices = config.get('device') if isinstance(config, dict) else None
    if not isinstance(devices, dict) or not devices:
        raise ValueError('Add a non-empty "device": {"pa-a": "192.0.2.10"} map to palo.json.')
    result = {}
    for name, address in devices.items():
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]*', name):
            raise ValueError('Device names must contain letters, numbers, dots, underscores or hyphens.')
        try:
            if not isinstance(address, str):
                raise ValueError()
            ip = ipaddress.ip_address(address)
        except ValueError:
            raise ValueError(f'{name}: device address must be an IPv4 or IPv6 address.') from None
        result[name] = f'[{ip}]' if ip.version == 6 else str(ip)
    return result


def run(root, child):
    temporary = None
    try:
        devices = load_devices(root)
        serials = {}
        failed = []
        for name, address in sorted(devices.items()):
            print(f'[palo] Reading serial for {name} ({address})...', flush=True)
            try:
                api = PanoramaAPI(dict(child, PANOS_HOSTNAME=address))
                response = api.request(type='op', cmd='<show><system><info></info></system></show>')
                serial = (response.findtext('./result/system/serial') or '').strip()
                if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9.-]*', serial) or serial.lower() in {'unknown', 'none', 'null'}:
                    raise APIError('Missing or invalid serial.', diagnostic='show system info: response contained no valid serial number.')
                serials[name] = serial
            except APIError as exc:
                failed.append(name)
                detail = exc.diagnostic or 'API request failed; check connectivity, credentials, TLS and XML API permissions.'
                print(f'[palo] {name} ({address}): {detail}', file=sys.stderr)
        if failed:
            print('[palo] serial.json was not changed because one or more devices failed.', file=sys.stderr)
            return 1
        # Replace atomically only after every host succeeds; never store API keys.
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', dir=root, prefix='.serial-', suffix='.tmp', delete=False) as file:
            temporary = Path(file.name)
            json.dump(serials, file, indent=2, sort_keys=True)
            file.write('\n')
        os.replace(temporary, root / 'serial.json')
        temporary = None
        print(f'[palo] Saved {len(serials)} serial(s) to {root / "serial.json"}.')
        return 0
    except (ValueError, OSError):
        print('[palo] Could not read device configuration or write serial.json. Check palo.json device entries and filesystem permissions.', file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print('[palo] Discovery interrupted; serial.json was not changed.', file=sys.stderr)
        return 130
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)

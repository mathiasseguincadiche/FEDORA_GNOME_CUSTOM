#!/usr/bin/env python3
"""Fail-closed inventory of persistent disks, UEFI vars and emulated TPM state."""
import json
import pathlib
import re
import sys
import xml.etree.ElementTree as ET


def plan(xml):
    root = ET.fromstring(xml)
    uuid = root.findtext('uuid', '')
    if not re.fullmatch(r'[0-9a-fA-F-]{36}', uuid):
        raise ValueError('Missing or invalid domain UUID')
    disks = []
    for disk in root.findall('./devices/disk'):
        if disk.get('device') != 'disk':
            continue
        source, driver, target = disk.find('source'), disk.find('driver'), disk.find('target')
        if (disk.get('type') != 'file' or source is None or driver is None
                or driver.get('type') != 'qcow2' or target is None):
            raise ValueError('VM backup supports file-backed qcow2 disks only; unsupported disk is not skipped')
        path = source.get('file', '')
        dev = target.get('dev', '')
        if not path.startswith('/') or not re.fullmatch(r'[a-zA-Z0-9_-]+', dev):
            raise ValueError('Invalid VM disk path or target')
        disks.append({'source': path, 'target': dev})
    state = []
    nvram = root.find('./os/nvram')
    if nvram is not None:
        source = nvram.find('source')
        path = (nvram.text or '').strip() or (source.get('file', '') if source is not None else '')
        if not path.startswith('/'):
            raise ValueError('Cannot resolve persistent NVRAM file')
        state.append(path)
    for tpm in root.findall('./devices/tpm/backend'):
        if tpm.get('type') != 'emulator' or tpm.find('encryption') is not None:
            raise ValueError('Unsupported TPM backend or encrypted TPM secret: explicit recovery procedure required')
        source = tpm.find('source')
        path = source.get('path', '') if source is not None else f'/var/lib/libvirt/swtpm/{uuid}'
        if not path.startswith('/'):
            raise ValueError('Cannot resolve emulated TPM state')
        state.append(path)
    if not disks:
        raise ValueError('No persistent VM disk found')
    return {'uuid': uuid, 'disks': disks, 'state_paths': state}


if __name__ == '__main__':
    try:
        print(json.dumps(plan(pathlib.Path(sys.argv[1]).read_text()), indent=2))
    except (ValueError, ET.ParseError) as error:
        sys.exit(str(error))

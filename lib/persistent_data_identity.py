#!/usr/bin/env python3
"""Bind / and /data to two explicitly approved physical NVMe identities."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import uuid


def read_json(*command):
    return json.loads(subprocess.check_output(command, text=True, timeout=15))


def filesystem(target, expected_model):
    rows = read_json('findmnt', '--json', '--target', target, '--output',
                     'SOURCE,TARGET,FSTYPE,UUID,OPTIONS').get('filesystems', [])
    if len(rows) != 1 or rows[0].get('target') != target:
        raise ValueError('not a dedicated mounted filesystem: ' + target)
    mount = rows[0]
    if target == '/data' and mount.get('fstype') != 'ext4':
        raise ValueError('/data must use EXT4')
    if 'rw' not in str(mount.get('options', '')).split(','):
        raise ValueError('filesystem is not read-write: ' + target)
    filesystem_uuid = str(uuid.UUID(mount.get('uuid', '')))
    source = str(mount.get('source', '')).split('[', 1)[0]
    if not source.startswith('/dev/'):
        raise ValueError('filesystem source is not a block device')
    ancestry = read_json('lsblk', '--json', '--inverse', '--paths', '--output',
                         'NAME,TYPE,MODEL,SERIAL,WWN', source)
    disks = {}

    def walk(node):
        if node.get('type') == 'disk':
            disks[node.get('name')] = node
        for child in node.get('children', []):
            walk(child)
    for node in ancestry.get('blockdevices', []):
        walk(node)
    if len(disks) != 1:
        raise ValueError('filesystem must have exactly one physical parent disk')
    disk = next(iter(disks.values()))
    serial = str(disk.get('serial') or '').strip()
    model = str(disk.get('model') or '').strip()
    if not re.fullmatch(r'/dev/nvme[0-9]+n[0-9]+', str(disk.get('name', ''))):
        raise ValueError('physical parent is not an NVMe namespace')
    if model != expected_model or not re.fullmatch(r'[A-Za-z0-9_.:+-]+', serial):
        raise ValueError('unidentified or unexpected NVMe model/serial')
    return {'filesystem_uuid': filesystem_uuid, 'fstype': mount['fstype'],
            'disk': {'model': model, 'serial': serial,
                     'wwn': str(disk.get('wwn') or '').strip()}}


def probe(expected_model):
    root, data = filesystem('/', expected_model), filesystem('/data', expected_model)
    if root['disk']['serial'] == data['disk']['serial']:
        raise ValueError('/ and /data share the same physical disk')
    return {'schema': 1, 'root': root, 'data': data}


def validate(expected, current):
    if expected != current:
        raise ValueError('physical disk or filesystem identity changed; review /data before enrollment')


def save(path, payload):
    path = Path(path)
    if path.is_symlink():
        raise ValueError('identity file must not be a symlink')
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix='.data-identity-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as handle:
            os.fchmod(handle.fileno(), 0o600)
            json.dump(payload, handle, sort_keys=True, indent=2)
            handle.write('\n')
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('probe', 'validate', 'enroll'))
    parser.add_argument('--model', required=True)
    parser.add_argument('--identity', type=Path)
    parser.add_argument('--confirm-serial')
    args = parser.parse_args()
    try:
        current = probe(args.model)
        if args.action == 'validate':
            if not args.identity or args.identity.is_symlink():
                raise ValueError('missing or unsafe approved storage identity')
            validate(json.loads(args.identity.read_text()), current)
        elif args.action == 'enroll':
            if not args.identity or args.confirm_serial != current['data']['disk']['serial']:
                raise ValueError('explicit confirmation of the /data NVMe serial is required')
            save(args.identity, current)
        print(json.dumps(current, sort_keys=True))
    except (ValueError, OSError, TypeError, KeyError, AttributeError, subprocess.SubprocessError) as error:
        parser.exit(1, 'Storage identity refused: ' + str(error) + '\n')


if __name__ == '__main__':
    main()

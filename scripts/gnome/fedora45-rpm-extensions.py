#!/usr/bin/env python3
"""Select and verify the same exact Fedora RPM extensions in lab and production."""
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]


def pins(root=ROOT):
    profile = json.loads((root / 'profiles/fedora45/gnome-rpms.json').read_text())
    packages = profile['packages']
    if profile['schema'] != 1 or set(packages) != {
            'gnome-shell-extension-dash-to-dock', 'gnome-shell-extension-appindicator'}:
        raise ValueError('Unexpected Fedora RPM roles')
    for package, record in packages.items():
        if not re.fullmatch(r'[0-9]+-[0-9]+[.]fc45', record['version_release']):
            raise ValueError('Invalid reviewed Fedora RPM version')
        if not re.fullmatch(r'[A-Za-z0-9@.+_-]+', record['uuid']):
            raise ValueError('Invalid Fedora RPM extension UUID')
    return packages


def verify():
    for package, record in pins().items():
        installed = subprocess.check_output(['rpm', '-q', '--qf', '%{VERSION}-%{RELEASE}', package], text=True)
        if installed != record['version_release']:
            raise ValueError('RPM differs from qualified candidate: ' + package)
        metadata = json.loads((Path('/usr/share/gnome-shell/extensions') / record['uuid'] / 'metadata.json').read_text())
        if metadata.get('uuid') != record['uuid'] or '51' not in map(str, metadata.get('shell-version', [])):
            raise ValueError('RPM does not declare GNOME 51 support: ' + package)


if __name__ == '__main__':
    try:
        if sys.argv[1:] == ['--specs']:
            for name, row in pins().items():
                print(name + '-' + row['version_release'])
        elif sys.argv[1:] == ['--verify']:
            verify()
        else:
            raise ValueError('Usage: fedora45-rpm-extensions.py --specs|--verify')
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error))

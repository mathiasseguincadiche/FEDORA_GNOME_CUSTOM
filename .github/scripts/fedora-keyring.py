#!/usr/bin/env python3
"""Fetch either official Fedora certificate encoding; callers still pin fingerprints."""
from pathlib import Path
import sys
import urllib.error
import urllib.request

URLS = ('https://fedoraproject.org/fedora.pgp', 'https://fedoraproject.org/fedora.gpg')


def download_bytes(url):
    with urllib.request.urlopen(url, timeout=30) as response:
        if not response.url.startswith('https://'):
            raise ValueError('HTTPS required for Fedora certificates')
        data = response.read(2 * 1024 * 1024 + 1)
    if not data or len(data) > 2 * 1024 * 1024:
        raise ValueError('Empty or oversized Fedora certificate bundle')
    # Reject HTTP-200 HTML error pages. Authenticity remains the responsibility
    # of the caller's exact fingerprint export and signed CHECKSUM verification.
    if not (data.startswith(b'-----BEGIN PGP PUBLIC KEY BLOCK-----') or data[0] in (0x99, 0xC6)):
        raise ValueError('Not an OpenPGP certificate encoding')
    return data


def fetch(target, download=download_bytes):
    errors = []
    for url in URLS:
        try:
            data = download(url)
        except (OSError, ValueError, urllib.error.URLError) as error:
            errors.append(url + ': ' + str(error))
            continue
        Path(target).write_bytes(data)
        return url
    raise ValueError('All official Fedora certificate endpoints failed: ' + '; '.join(errors))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit('Usage: fedora-keyring.py OUTPUT')
    try:
        print('Fedora certificates downloaded from ' + fetch(sys.argv[1]))
    except (OSError, ValueError) as error:
        raise SystemExit(str(error))

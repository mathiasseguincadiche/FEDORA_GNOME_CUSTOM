#!/usr/bin/env python3
"""Validate GNOME metadata structurally, independent of JSON formatting."""
import json
import sys

try:
    path, uuid, shell = sys.argv[1:]
    with open(path, encoding='utf-8') as handle:
        metadata = json.load(handle)
    if not isinstance(metadata, dict) or metadata.get('uuid') != uuid:
        raise ValueError('extension UUID mismatch')
    versions = metadata.get('shell-version')
    if not isinstance(versions, list) or shell not in versions:
        raise ValueError(f'extension does not declare GNOME Shell {shell}')
except (OSError, ValueError, TypeError) as error:
    print(f'Invalid extension metadata: {error}', file=sys.stderr)
    sys.exit(1)

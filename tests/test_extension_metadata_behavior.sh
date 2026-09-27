#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT/scripts/gnome/validate-extension-metadata.py" <<'PY'
import json, pathlib, subprocess, sys, tempfile
validator = sys.argv[1]
with tempfile.TemporaryDirectory() as directory:
    path = pathlib.Path(directory) / 'metadata.json'
    cases = [
        ({'uuid': 'fixture@test', 'shell-version': ['50']}, True),
        ({'uuid': 'fixture@test', 'shell-version': ['49'], 'version-name': '50'}, False),
        ({'uuid': 'wrong@test', 'shell-version': ['50']}, False),
        ({'uuid': 'fixture@test', 'shell-version': '50'}, False),
        ({'uuid': 'fixture@test'}, False),
        ([], False),
    ]
    for payload, expected in cases:
        path.write_text(json.dumps(payload, separators=(',', ':')))
        result = subprocess.run([sys.executable, validator, str(path), 'fixture@test', '50'], capture_output=True)
        assert (result.returncode == 0) == expected, payload
    path.write_text('{broken')
    assert subprocess.run([sys.executable, validator, str(path), 'fixture@test', '50'], capture_output=True).returncode != 0
print('extension metadata behavior: PASS')
PY

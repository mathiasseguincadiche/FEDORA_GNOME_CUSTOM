#!/usr/bin/env python3
"""Check dispatcher coverage; this is explicitly not a workstation PASS."""
import json
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parents[2]
plan = [line.split('|')[0] for line in
        (root / 'manifests/module-plan.conf').read_text().splitlines()
        if line and not line.startswith('#')]
report = json.loads((root / 'reports/run-ci-installer-audit.json').read_text())
assert report['mode'] == 'dry-run'
assert [row['module'] for row in report['modules']] == plan
assert all(row['phase'] in {'precheck', 'postcheck', 'complete'}
           for row in report['modules']), 'Unexpected bootstrap/source/contract/plan/apply failure'
assert int(sys.argv[1]) != 0 and report['overall'] == 'FAIL', \
    'A container must not certify the physical workstation'
assert not list((root / 'state').glob('dryrun-*.ok')), 'Audit wrote an APPLY proof'
print(f'PASS: dispatcher visited {len(plan)} entries; hardware certification remains FAIL')

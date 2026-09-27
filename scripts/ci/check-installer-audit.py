#!/usr/bin/env python3
"""Check dispatcher coverage; this is explicitly not a workstation PASS.

On failure, every offending module is printed as a GitHub Actions `::error::`
annotation so the cause is readable from the PR page without downloading logs.
"""
import json
import os
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parents[2]
run_id = os.environ.get('RUN_ID', 'ci-installer-audit')
errors = []


def fail(message):
    errors.append(message)


plan = [line.split('|')[0] for line in
        (root / 'manifests/module-plan.conf').read_text().splitlines()
        if line and not line.startswith('#')]
report_path = root / f'reports/run-{run_id}.json'
if not report_path.is_file():
    fail(f'missing report {report_path.name} (bootstrap failed before the catalog ran)')
else:
    report = json.loads(report_path.read_text())
    if report.get('mode') != 'dry-run':
        fail(f"unexpected mode {report.get('mode')!r}")
    visited = [row['module'] for row in report.get('modules', [])]
    if visited != plan:
        missing = [m for m in plan if m not in visited]
        fail(f'catalog not fully visited ({len(visited)}/{len(plan)}); first missing: {missing[:3]}')
    for row in report.get('modules', []):
        if row['phase'] not in {'precheck', 'postcheck', 'complete'}:
            fail(f"{row['module']}: unexpected {row['phase']} failure rc={row['rc']} ({row['detail']})")
    if int(sys.argv[1]) == 0 or report.get('overall') != 'FAIL':
        fail('a container must not certify the physical workstation')
if list((root / 'state').glob('dryrun-*.ok')):
    fail('audit wrote an APPLY proof')

if errors:
    for message in errors:
        print(f'::error title=installer audit::{message}')
    sys.exit(1)
print(f'PASS: dispatcher visited {len(plan)} entries; hardware certification remains FAIL')

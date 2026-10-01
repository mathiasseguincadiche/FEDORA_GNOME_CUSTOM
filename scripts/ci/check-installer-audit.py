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

# Only documented container limitations may fail. Each exception is scoped to
# a module, phase and exit code; plan/apply/source/internal failures always fail.
EXPECTED_BLOCKERS = {
    ("system.preflight", "precheck", 20): "container runs as root",
    ("system.kernel", "precheck", 20): "Secure Boot cannot be proven",
    ("gnome.settings", "precheck", 20): "no GNOME settings schemas/session",
    ("kvm.stack", "precheck", 20): "no real operator in root container",
    ("kvm.storage", "precheck", 20): "no dedicated /data mount",
}



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
        if row.get('state') == 'OK' and row.get('phase') == 'complete' and row.get('rc') == 0:
            continue
        blocker = (row.get('module'), row.get('phase'), row.get('rc'))
        if row.get('state') != 'KO' or blocker not in EXPECTED_BLOCKERS:
            fail(f"{row['module']}: unexpected {row['phase']} failure rc={row['rc']} ({row['detail']})")
        else:
            print(f"EXPECTED BLOCK: {blocker}: {EXPECTED_BLOCKERS[blocker]}")
    if int(sys.argv[1]) == 0 or report.get('overall') != 'FAIL':
        fail('a container must not certify the physical workstation')
if list((root / 'state').glob('dryrun-*.ok')):
    fail('audit wrote an APPLY proof')

if errors:
    for message in errors:
        print(f'::error title=installer audit::{message}')
    sys.exit(1)
print(f'PASS: dispatcher visited {len(plan)} entries; hardware certification remains FAIL')

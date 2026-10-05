#!/usr/bin/env python3
"""An interactive rerun invalidates old evidence even if a precheck fails."""
import os
from pathlib import Path
import subprocess
import tempfile

SOURCE = Path(__file__).resolve().parents[1] / "diagnostics/portal-functional-doctor"
BOOTSTRAP = """
engine_bootstrap() { :; }
repo_commit() { printf '%s' test-commit; }
physical_runtime_evidence_path() { printf '%s/final/evidence/%s.ok' "$STATE_ROOT" "$1"; }
ui_check() { :; }
EXIT_USAGE=64
EXIT_PRECHECK_FAILED=21
EXIT_POSTCHECK_FAILED=31
"""
PORTAL = """#!/usr/bin/env bash
exit 1
"""


def exercise(scope, desktop, interactive):
    with tempfile.TemporaryDirectory(prefix="fgc-portal-evidence-") as directory:
        root = Path(directory)
        (root / "diagnostics").mkdir()
        (root / "lib").mkdir()
        (root / "lib/bootstrap.sh").write_text(BOOTSTRAP, encoding="utf-8")
        (root / "diagnostics/portal-functional-doctor").write_text(
            SOURCE.read_text(encoding="utf-8"), encoding="utf-8")
        portal = root / "diagnostics/portal-doctor"
        portal.write_text(PORTAL, encoding="utf-8")
        portal.chmod(0o755)
        state = root / "state"
        gate2 = state / "validation/portal-functional-gate2-test-commit.ok"
        gate3 = state / "final/evidence/portal-functional.ok"
        certificate = state / "final/certified.ok"
        unrelated = state / "final/evidence/audio.ok"
        for marker in (gate2, gate3, certificate, unrelated):
            marker.parent.mkdir(parents=True, exist_ok=True)
            marker.write_text("status=PASS\n", encoding="utf-8")

        arguments = ["--quiet", "--" + scope]
        if interactive:
            arguments.insert(0, "--interactive")
        result = subprocess.run(
            ["bash", str(root / "diagnostics/portal-functional-doctor"), *arguments],
            env={**os.environ, "STATE_ROOT": str(state),
                 "XDG_CURRENT_DESKTOP": desktop, "XDG_SESSION_TYPE": "wayland"},
            capture_output=True, text=True, timeout=10)
        expected = 21 if desktop == "KDE" else 31
        if result.returncode != expected:
            raise AssertionError(
                f"{scope}/{desktop}/{interactive}: unexpected exit {result.returncode}\n"
                + result.stderr)
        target = gate2 if scope == "gate2" else gate3
        if interactive and target.exists():
            raise AssertionError(f"{scope}/{desktop}: old interactive evidence survived")
        if not interactive and not target.exists():
            raise AssertionError(f"{scope}/{desktop}: read-only check erased evidence")
        if certificate.exists() != (not interactive or scope != "gate3"):
            raise AssertionError(f"{scope}/{desktop}: wrong final certificate lifecycle")
        other = gate3 if scope == "gate2" else gate2
        if not other.exists() or not unrelated.exists():
            raise AssertionError(f"{scope}/{desktop}: unrelated evidence was erased")


for selected_scope in ("gate2", "gate3"):
    for selected_desktop in ("KDE", "GNOME"):
        exercise(selected_scope, selected_desktop, interactive=True)
        exercise(selected_scope, selected_desktop, interactive=False)
print("Portal evidence lifecycle: PASS (session/service failures, both gates, read-only preservation)")

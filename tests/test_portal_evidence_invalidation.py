#!/usr/bin/env python3
"""An interactive rerun invalidates old evidence even if a precheck fails."""
import os
from pathlib import Path
import pty
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "diagnostics/portal-functional-doctor"
BOOTSTRAP = """
engine_bootstrap() { :; }
repo_commit() { printf '%s' test-commit; }
physical_runtime_evidence_path() { printf '%s/final/evidence/%s.ok' "$STATE_ROOT" "$1"; }
ui_check() { printf '%s|%s|%s\n' "$@"; }
ui_error() { printf '%s\n' "$*" >&2; }
effective_config_sha256() { printf 'fixture-config'; }
workstation_runtime_fingerprint() { printf 'fixture-hardware'; }
EXIT_USAGE=64
EXIT_PRECHECK_FAILED=21
EXIT_POSTCHECK_FAILED=31
EXIT_SECURITY_BLOCK=50
"""
VALIDATION = """
validation_require_installed_runtime() {
  [[ "${TEST_INSTALLED:-true}" == true ]] || {
    printf 'Installed runtime required\n' >&2
    return 50
  }
}
validation_require_chain() { return 1; }
"""
PORTAL = """#!/usr/bin/env bash
exit 1
"""


def exercise(desktop, interactive, installed=True, retired_scope=False):
    with tempfile.TemporaryDirectory(prefix="fgc-portal-evidence-") as directory:
        root = Path(directory)
        (root / "diagnostics").mkdir()
        (root / "lib").mkdir()
        (root / "lib/bootstrap.sh").write_text(BOOTSTRAP, encoding="utf-8")
        (root / "lib/validation_gates.sh").write_text(VALIDATION, encoding="utf-8")
        (root / "diagnostics/portal-functional-doctor").write_text(
            SOURCE.read_text(encoding="utf-8"), encoding="utf-8")
        portal = root / "diagnostics/portal-doctor"
        portal.write_text(PORTAL, encoding="utf-8")
        portal.chmod(0o755)
        state = root / "state"
        live = state / "validation/imported/live.json"
        gate3 = state / "final/evidence/portal-functional.ok"
        certificate = state / "final/certified.ok"
        unrelated = state / "final/evidence/audio.ok"
        for marker in (live, gate3, certificate, unrelated):
            marker.parent.mkdir(parents=True, exist_ok=True)
            marker.write_text("status=PASS\n", encoding="utf-8")

        arguments = ["--quiet", "--gate2" if retired_scope else "--gate3"]
        if interactive:
            arguments.insert(0, "--interactive")
        result = subprocess.run(
            ["bash", str(root / "diagnostics/portal-functional-doctor"), *arguments],
            env={**os.environ, "STATE_ROOT": str(state),
                 "XDG_CURRENT_DESKTOP": desktop, "XDG_SESSION_TYPE": "wayland",
                 "TEST_INSTALLED": str(installed).lower()},
            capture_output=True, text=True, timeout=10)
        expected = (64 if retired_scope else
                    50 if interactive and not installed else
                    21 if desktop == "KDE" else 31)
        if result.returncode != expected:
            raise AssertionError(
                f"{desktop}/{interactive}/{installed}: unexpected exit {result.returncode}\n"
                + result.stderr)
        preserved = not interactive or retired_scope
        if gate3.exists() != preserved or certificate.exists() != preserved:
            raise AssertionError(f"{desktop}/{interactive}: wrong installed evidence lifecycle")
        if not live.exists() or not unrelated.exists():
            raise AssertionError(f"{desktop}: unrelated or Live evidence was erased")


def exercise_ux_scope():
    """The installed UX matrix cannot sign custom settings from the Live gate."""
    with tempfile.TemporaryDirectory(prefix="fgc-installed-ux-") as directory:
        root = Path(directory)
        (root / "scripts/validation").mkdir(parents=True)
        (root / "diagnostics").mkdir()
        (root / "lib").mkdir()
        (root / "lib/bootstrap.sh").write_text(BOOTSTRAP)
        (root / "lib/validation_gates.sh").write_text(VALIDATION)
        script = root / "scripts/validation/gnome-ux-matrix.sh"
        script.write_text((ROOT / "scripts/validation/gnome-ux-matrix.sh").read_text())
        applications = root / "diagnostics/application-usage-doctor"
        applications.write_text((ROOT / "diagnostics/application-usage-doctor").read_text())
        env = dict(os.environ, STATE_ROOT=str(root / "state"),
                   XDG_CURRENT_DESKTOP="GNOME", XDG_SESSION_TYPE="wayland")
        result = subprocess.run(["bash", str(script), "gate2"], env=env,
                                text=True, capture_output=True, timeout=10)
        assert result.returncode == 64, result.stderr
        result = subprocess.run(["bash", str(script), "status"], env=env,
                                text=True, capture_output=True, timeout=10)
        assert result.returncode == 0 and "Gate 3 GNOME UX" in result.stdout
        assert "Gate 2 GNOME UX" not in result.stdout
        for installed, expected in ((False, 50), (True, 21)):
            terminal, slave = pty.openpty()
            try:
                result = subprocess.run(["bash", str(script), "gate3"],
                                        env=env | {"TEST_INSTALLED": str(installed).lower()},
                                        stdin=slave, stdout=slave, stderr=subprocess.PIPE,
                                        text=True, timeout=10)
                assert result.returncode == expected, result.stderr
            finally:
                os.close(slave)
                os.close(terminal)
        terminal, slave = pty.openpty()
        try:
            result = subprocess.run(["bash", str(applications), "--interactive"],
                                    env=env | {"TEST_INSTALLED": "false",
                                               "XDG_RUNTIME_DIR": str(root / "missing-runtime")},
                                    stdin=slave, stdout=slave, stderr=subprocess.PIPE,
                                    text=True, timeout=10)
            assert result.returncode == 50, result.stderr
        finally:
            os.close(slave)
            os.close(terminal)
        assert not list(root.glob("state/**/*.ok")), "failed prechecks produced UX evidence"


def exercise_ux_rerun(case):
    """Failed interactive UX attempts cannot leave an earlier PASS authoritative."""
    with tempfile.TemporaryDirectory(prefix="fgc-ux-rerun-") as directory:
        root = Path(directory)
        (root / "scripts/validation").mkdir(parents=True)
        (root / "diagnostics").mkdir()
        (root / "lib").mkdir()
        (root / "bin").mkdir()
        (root / "home").mkdir()
        (root / "lib/bootstrap.sh").write_text(BOOTSTRAP + """
is_true() { [[ "${1:-false}" == true ]]; }
FINAL_CERT_MIN_SUSPEND_CYCLES=5
ENABLE_KVM=false
""")
        (root / "lib/validation_gates.sh").write_text("""
validation_require_installed_runtime() { [[ "$TEST_CASE" != runtime ]] || return 50; }
validation_require_chain() { [[ "$TEST_CASE" != chain ]]; }
""")
        script = root / "scripts/validation/gnome-ux-matrix.sh"
        script.write_text((ROOT / "scripts/validation/gnome-ux-matrix.sh").read_text())
        for name, rejected_case, code in (
            ("gnome-desktop-integration-doctor", "desktop-preflight", 31),
            ("portal-functional-doctor", "portal-preflight", 32),
        ):
            doctor = root / "diagnostics" / name
            doctor.write_text(f"#!/usr/bin/env bash\n"
                              f'[[ "$TEST_CASE" != {rejected_case} ]] || exit {code}\n')
            doctor.chmod(0o755)
        nautilus = root / "bin/nautilus"
        nautilus.write_text("#!/usr/bin/env bash\nexit 0\n")
        nautilus.chmod(0o755)
        state = root / "state"
        marker = state / "final/evidence/gnome-ux.ok"
        certificate = state / "final/certified.ok"
        live = state / "validation/imported/live.json"
        unrelated = state / "final/evidence/audio.ok"
        for file in (marker, certificate, live, unrelated):
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text("status=PASS\nworkstation_fingerprint=fixture-hardware\n"
                            "effective_config_sha256=fixture-config\n")
        for number in range(4 if case == "suspend-cycles" else 5):
            (marker.parent / f"suspend-{number}.ok").write_text("fingerprint=fixture-hardware\n")
        env = dict(os.environ, STATE_ROOT=str(state), TEST_CASE=case,
                   XDG_CURRENT_DESKTOP="KDE" if case == "session" else "GNOME",
                   XDG_SESSION_TYPE="wayland", HOME=str(root / "home"),
                   PATH=str(root / "bin") + os.pathsep + os.environ["PATH"])
        # Consultation is read-only, including with an old result on disk.
        status = subprocess.run(["bash", str(script), "status"], env=env,
                                text=True, capture_output=True, timeout=10)
        assert status.returncode == 0 and status.stdout.startswith("OK|"), status.stderr
        assert marker.exists() and certificate.exists()
        if case == "status":
            assert live.exists() and unrelated.exists()
            return
        terminal, slave = pty.openpty()
        try:
            if case == "manual-decline":
                os.write(terminal, b"FAIL\n")
            result = subprocess.run(["bash", str(script), "gate3"], env=env,
                                    stdin=slave, stdout=slave, stderr=subprocess.PIPE,
                                    text=True, timeout=10)
        finally:
            os.close(slave)
            os.close(terminal)
        expected = {"runtime": 50, "desktop-preflight": 31, "portal-preflight": 32}.get(case, 21)
        assert result.returncode == expected, f"{case}: {result.returncode}: {result.stderr}"
        assert not marker.exists(), f"{case}: earlier UX PASS survived a failed rerun"
        assert not certificate.exists(), f"{case}: earlier final certificate survived a failed rerun"
        assert live.exists() and unrelated.exists(), f"{case}: unrelated evidence was erased"
        if case == "manual-decline":
            assert "Visual check refused" in result.stderr, result.stderr


for installed_runtime in (True, False):
    for selected_desktop in ("KDE", "GNOME"):
        exercise(selected_desktop, interactive=True, installed=installed_runtime)
        exercise(selected_desktop, interactive=False, installed=installed_runtime)
exercise("GNOME", interactive=True, retired_scope=True)
exercise_ux_scope()
for failed_ux_stage in ("status", "session", "runtime", "chain", "suspend-cycles",
                        "desktop-preflight", "portal-preflight", "manual-decline"):
    exercise_ux_rerun(failed_ux_stage)
print("Installed portal/UX evidence lifecycle: PASS (Live refusal, failed reruns, human refusal, read-only preservation)")

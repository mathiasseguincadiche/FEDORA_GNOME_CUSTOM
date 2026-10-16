#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import copy
import importlib.util
import pathlib
import sys
root = pathlib.Path(sys.argv[1])
spec = importlib.util.spec_from_file_location("lab", root / ".github/scripts/fedora-lab-report.py")
lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lab)
r = lab.initialize("a" * 40)
r["checks"] = {k: "PASS" for k in lab.REQUIRED}
r["evidence"] = {
    "boot_id": "11111111-1111-1111-1111-111111111111",
    "reboot_id": "22222222-2222-2222-2222-222222222222",
    "restored_boot_id": "33333333-3333-3333-3333-333333333333",
    "rebuilt_boot_id": "44444444-4444-4444-4444-444444444444",
    "files_archive_id": "a" * 64, "cold_archive_id": "b" * 64,
    "disk_sha256": "c" * 64, "nvram_sha256": "d" * 64,
    "recovery_network": "restrict=on", "encryption": "none", "tpm_canary": "PASS",
    "session_shutdown": "gnome-logout",
    "fedora_release": "44", "gnome_major": "50", "extension_mode": "curated", "curated_extensions": "six-active",
}
assert lab.finalize(copy.deepcopy(r))["verdict"] == "PASS"
def rejected(changed):
    try:
        lab.finalize(changed)
    except (ValueError, KeyError):
        return
    raise AssertionError("incomplete or false lab evidence was accepted")
for check in lab.REQUIRED:
    for verdict in ("PENDING", "FAIL", "DEFERRED"):
        changed = copy.deepcopy(r)
        changed["checks"][check] = verdict
        rejected(changed)
for key, value in (("reboot_id", r["evidence"]["boot_id"]),
                   ("restored_boot_id", r["evidence"]["reboot_id"]),
                   ("rebuilt_boot_id", "not-a-boot"),
                   ("cold_archive_id", "latest"),
                   ("encryption", "repokey"),
                   ("recovery_network", "off"),
                   ("tpm_canary", "DEFERRED"),
                   ("session_shutdown", "direct-systemctl")):
    changed = copy.deepcopy(r)
    changed["evidence"][key] = value
    rejected(changed)
preview = copy.deepcopy(r)
preview.update(release=45, gnome_major=51, extension_mode="native")
preview["evidence"].update(fedora_release="45", gnome_major="51", extension_mode="native", curated_extensions="DEFERRED")
assert lab.finalize(copy.deepcopy(preview))["verdict"] == "PASS"
candidate = copy.deepcopy(r)
candidate.update(release=45, gnome_major=51, extension_mode="curated")
candidate["evidence"].update(fedora_release="45", gnome_major="51", extension_mode="curated")
assert lab.finalize(copy.deepcopy(candidate))["verdict"] == "PASS"
candidate["evidence"]["curated_extensions"] = "DEFERRED"
rejected(candidate)
preview["evidence"]["curated_extensions"] = "six-active"
rejected(preview)
for gate in lab.DEFERRED:
    changed = copy.deepcopy(r)
    changed["deferred"][gate] = "PASS"
    rejected(changed)
rejected(lab.initialize("a" * 40))
# The mandatory contracts context must actually wait for the reusable VM job.
tests = (root / ".github/workflows/tests.yml").read_text()
assert "needs: [logic-contracts, installer-audit, borg-fedora, fedora-gnome-vm, fedora45-gnome-vm, upstream-kernel, rocky-devops-vm]" in tests
assert "if: ${{ always() }}" in tests.split("\n  contracts:\n", 1)[1]
assert "require-jobs-success.py logic-contracts installer-audit borg-fedora fedora-gnome-vm fedora45-gnome-vm upstream-kernel rocky-devops-vm" in tests
assert "uses: ./.github/workflows/fedora-gnome-vm.yml" in tests
assert "uses: ./.github/workflows/fedora45-gnome-vm.yml" in tests
for script in (".github/scripts/fedora45-ci-install-extension.sh", ".github/scripts/fedora45-ci-extension-audit.py", ".github/scripts/fedora45-ci-validate-candidate.py"):
    assert (root / script).is_file()
guest = (root / ".github/scripts/fedora-gnome-guest.sh").read_text()
host = (root / ".github/scripts/fedora-gnome-vm.sh").read_text()
# The fourth extension has no dedicated *_SCHEMA identifier. Do not invent one.
candidate_validator = (root / ".github/scripts/fedora45-ci-validate-candidate.py").read_text()
candidate_installer = (root / ".github/scripts/fedora45-ci-install-extension.sh").read_text()
assert 'if key not in canonical:' in candidate_validator
assert 'if [[ -n "${!schema_var:-}" ]]' in candidate_installer
assert 'if [[ "$LAB_RELEASE:$LAB_EXTENSION_MODE" == 45:curated ]]' in host
assert 'if [[ "$LAB_RELEASE:$LAB_EXTENSION_MODE" == 45:curated ]]' in guest
assert "fedora45-ci-extension-audit.py" in guest
# The restored GNOME 51 session occasionally returns a non-zero list query.
# A bounded retry is allowed only as transport, never as certification.
extension_audit = (root / ".github/scripts/fedora45-ci-extension-audit.py").read_text()
extension_list = (root / ".github/scripts/fedora45-ci-extension-list.py").read_text()
assert 'extension_list.list_extensions("--active")' in extension_audit
assert 'extension_list.list_extensions("--enabled")' in extension_audit
assert 'if completed.returncode == 0:' in extension_list
assert 'if attempt < attempts:' in extension_list
assert 'raise RuntimeError(' in extension_list
assert 'gnome-extensions", "list"' in extension_list
assert "journal_health 0" in guest
# A non-zero gnome-extensions info probe must never abort all of session
# validation before the next bounded attempt or be considered ACTIVE.
assert 'if output="$(as_user timeout --signal=TERM --kill-after=5s 20s gnome-extensions info "$uuid" 2>&1)"; then' in guest
assert "for attempt in {1..60}; do" in guest
assert "as_user timeout --signal=TERM --kill-after=5s 20s gnome-extensions info" in guest
assert "if (( attempt < 60 )); then sleep 2; fi" in guest
assert 'echo "GNOME extension $uuid not confirmed enabled and ACTIVE' in guest
# The GTK4-DING subprocess race must be fixed inside the signed-archive
# descendant, not by disabling any extension during logout or silencing cores.
ding_fix = (root / ".github/scripts/fedora45-ci-ding-shutdown-fix.py").read_text()
assert 'def patched_source(original: bytes)' in ding_fix
assert '"    disable() {\\n        this.isEnabled = false;' in ding_fix
assert 'if (!this.isEnabled || !client || this.waylandClient !== client)' in ding_fix
assert 'if (!this.isEnabled)\\n            return;' in ding_fix
assert 'hashlib.sha256(archive.read_bytes()).hexdigest() != profile["DING_SHA256"]' in ding_fix
assert 'if current != expected:' in ding_fix
assert 'fedora45-ci-ding-shutdown-fix.py" apply' in candidate_installer
assert 'fedora45-ci-ding-shutdown-fix.py"), "verify"' in (root / ".github/scripts/fedora45-ci-extension-audit.py").read_text()
assert 'source "$REPO/profiles/fedora45/gnome-extensions.lock"' in guest
assert 'source "$ROOT/profiles/fedora45/gnome-extensions.lock"' in host
# The real GNOME lab must close CI-owned GUI clients before logging out.
# Keep both the actual logout and the strict post-logout journal gate.
guest = (root / ".github/scripts/fedora-gnome-guest.sh").read_text()
logout = guest.split("  end-session)", 1)[1].split("  session)", 1)[0]
assert "fgc-lab-ptyxis.service fgc-lab-nautilus.service" in logout
assert 'as_user systemctl --user stop "$unit"' in logout
assert logout.index('as_user systemctl --user stop "$unit"') < logout.index("gnome-session-quit --logout --no-prompt")
assert "require_session" in logout
assert "journal_health 0" in logout
# A software-rendered QEMU desktop needs bounded time to drain stopped window
# clients; this cannot hide an ABRT or a failed GNOME systemd user unit.
assert "TimeoutStopSec=30s" in guest
assert "org.gnome.Shell@user.service.d" in guest
assert guest.index("90-fgc-lab-shutdown.conf") < guest.index('as_user systemctl --user daemon-reload')
assert logout.index('as_user systemctl --user stop "$unit"') < logout.index("sleep 3")
assert logout.index("sleep 3") < logout.index("gnome-session-quit --logout --no-prompt")
assert "journal_health 0" in logout
# Root must not reopen a lab-user-owned file in /tmp: fs.protected_regular
# rejects that under sticky directories. Package in root-owned private storage
# and publish the complete archive with restrictive permissions for SCP.
collect = guest.split("  collect)", 1)[1].split("  health|previous-health)", 1)[0]
assert "mktemp /var/lib/fgc-lab/.evidence.XXXXXXXX.tar.gz" in collect
assert 'tar -C /tmp/fgc-evidence -czf "$evidence_tmp" .' in collect
assert 'chmod 0600 "$evidence_tmp"' in collect
assert 'mv -f -- "$evidence_tmp" /tmp/fgc-evidence.tar.gz' in collect
assert 'as_user test -r /tmp/fgc-evidence.tar.gz' in collect
assert "tar -C /tmp/fgc-evidence -czf /tmp/fgc-evidence.tar.gz" not in collect
host = (root / ".github/scripts/fedora-gnome-vm.sh").read_text()
assert "preserve_hostname: false" in host
assert "hostname: fgc-fedora-ci" in host
assert "preserve_hostname: true" not in host
# Current operator guide must match the configured default channel.
assert 'KERNEL_CHANNEL="vanilla"' in (root / "config/kernel.conf").read_text()
guide = (root / "docs/THREE_GATE_VALIDATION.md").read_text()
assert "CachyOS" not in guide
assert "manuellement par leur propriétaire" in guide
assert "Linux amont" in guide
# A skipped required context must not turn a failed dependency into success.
spec = importlib.util.spec_from_file_location("jobs", root / ".github/scripts/require-jobs-success.py")
jobs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(jobs)
required = ["logic-contracts", "installer-audit", "borg-fedora", "fedora-gnome-vm", "fedora45-gnome-vm", "upstream-kernel", "rocky-devops-vm"]
needs = {name: {"result": "success"} for name in required}
assert jobs.successful(needs, required)
for name in required:
    for result in ("skipped", "failure", "cancelled", None):
        broken = copy.deepcopy(needs)
        broken[name]["result"] = result
        assert not jobs.successful(broken, required)
assert not jobs.successful({}, required)
# Host resets, shutdown and untrusted boolean values are not OS reboot proof.
spec = importlib.util.spec_from_file_location("qmp", root / ".github/scripts/fedora-qmp-reboot.py")
qmp = importlib.util.module_from_spec(spec)
spec.loader.exec_module(qmp)
assert qmp.guest_reset({"event": "RESET", "data": {"guest": True, "reason": "guest-reset"}})
for event in ({}, {"event": "SHUTDOWN", "data": {"guest": True, "reason": "guest-shutdown"}},
              {"event": "RESET", "data": {"guest": False, "reason": "host-qmp-system-reset"}},
              {"event": "RESET", "data": {"guest": "true", "reason": "guest-reset"}},
              {"event": "RESET", "data": {"guest": True, "reason": "guest-panic"}}):
    assert not qmp.guest_reset(event)
print("Fedora lab evidence: PASS (missing exercises, stale boots, archive identity, isolation, encryption, deferred gates)")
PY

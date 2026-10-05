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
for gate in lab.DEFERRED:
    changed = copy.deepcopy(r)
    changed["deferred"][gate] = "PASS"
    rejected(changed)
rejected(lab.initialize("a" * 40))
# The mandatory contracts context must actually wait for the reusable VM job.
tests = (root / ".github/workflows/tests.yml").read_text()
assert "needs: [logic-contracts, installer-audit, borg-fedora, fedora-gnome-vm, upstream-kernel, rocky-devops-vm]" in tests
assert "if: ${{ always() }}" in tests.split("\n  contracts:\n", 1)[1]
assert "require-jobs-success.py logic-contracts installer-audit borg-fedora fedora-gnome-vm upstream-kernel rocky-devops-vm" in tests
assert "uses: ./.github/workflows/fedora-gnome-vm.yml" in tests
# Current operator guide must match the configured default channel.
assert 'KERNEL_CHANNEL="vanilla"' in (root / "config/kernel.conf").read_text()
guide = (root / "docs/THREE_GATE_VALIDATION.md").read_text()
assert "CachyOS" not in guide
assert "--include-vms --staging-root" in guide
assert "Linux amont" in guide
# A skipped required context must not turn a failed dependency into success.
spec = importlib.util.spec_from_file_location("jobs", root / ".github/scripts/require-jobs-success.py")
jobs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(jobs)
required = ["logic-contracts", "installer-audit", "borg-fedora", "fedora-gnome-vm", "upstream-kernel", "rocky-devops-vm"]
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

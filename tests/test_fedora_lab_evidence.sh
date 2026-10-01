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
                   ("tpm_canary", "DEFERRED")):
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
assert "needs: [installer-audit, borg-fedora, fedora-gnome-vm]" in tests
assert "uses: ./.github/workflows/fedora-gnome-vm.yml" in tests
# Current operator guide must match the configured default channel.
assert 'KERNEL_CHANNEL="cachyos"' in (root / "config/kernel.conf").read_text()
guide = (root / "docs/THREE_GATE_VALIDATION.md").read_text()
assert "Kernel Vanilla" not in guide
assert "--include-vms --staging-root" in guide
assert "CachyOS BORE" in guide
print("Fedora lab evidence: PASS (missing exercises, stale boots, archive identity, isolation, encryption, deferred gates)")
PY

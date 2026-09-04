#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
engine="$ROOT/scripts/upgrade/upgrade-lifecycle.sh"
policy="$ROOT/config/fedora-upgrade.policy"
workflow="$ROOT/.github/workflows/fedora45-qualification.yml"

[[ -x "$engine" ]]
[[ -r "$policy" ]]

grep -Fxq 'FEDORA_UPGRADE_SOURCE_RELEASE=44' "$policy"
grep -Fxq 'FEDORA_UPGRADE_TARGET_RELEASE=45' "$policy"
grep -Fxq 'FEDORA_UPGRADE_MAX_HOPS=1' "$policy"
grep -Fxq 'FEDORA_UPGRADE_REQUIRE_FINAL_RELEASE=true' "$policy"
grep -Fxq 'FEDORA_UPGRADE_ALLOW_ALLERASING=false' "$policy"
grep -Fxq 'FEDORA_UPGRADE_AUTOMATIC_REBOOT=false' "$policy"

grep -Fq "upgrade-lifecycle.sh\" \"\${@:2}\"" "$ROOT/control.sh"
grep -Fq "dnf5 --releasever=\"\$target\" repoclosure --json" "$engine"
grep -Fq "distro-sync --store=\"\$txdir/transaction\"" "$engine"
grep -Fq 'apply_gate_require_backup' "$engine"
grep -Fq 'current_gold_cert_valid' "$engine"
grep -Fq 'qualification_fresh' "$engine"
grep -Fq 'final_release_available' "$engine"
grep -Fq "system-upgrade download --releasever=\"\$target\"" "$engine"
grep -Fq 'There is deliberately no automatic reboot/upgrade command' "$engine"
grep -Fq 'sudo dnf5 system-upgrade reboot' "$engine"
grep -Fq 'Old Golden certificate unexpectedly remains valid' "$engine"

# A Fedora major release is itself part of the runtime fingerprint, so old
# Golden evidence cannot survive a 44 -> 45 transition by accident.
grep -Fq "printf 'fedora_release=%s\\n'" "$ROOT/lib/baseline.sh"

# Current GNOME 50 reviewed artifacts are an explicit blocker for Fedora 45 /
# GNOME 51 until compatible reviewed pins are committed.
grep -Fq 'Golden GNOME extension artifacts are still pinned to GNOME Shell 50' "$engine"

[[ -r "$workflow" ]]
grep -Fq 'container: fedora:45' "$workflow"
grep -Fq 'Fedora 45 / GNOME 51 readiness' "$workflow"
grep -Fq 'fedora45-qualification-report.txt' "$workflow"

grep -Fq 'test_fedora_upgrade_lifecycle_contract.sh' "$ROOT/.github/workflows/tests.yml"

printf 'PASS: Fedora N+1 lifecycle is qualification-first and fail-closed\n'

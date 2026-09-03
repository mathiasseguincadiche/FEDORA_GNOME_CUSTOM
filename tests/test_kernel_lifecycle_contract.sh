#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

conf="$ROOT/config/kernel.conf"
policy="$ROOT/config/kernel-lifecycle.policy"
lib="$ROOT/lib/kernel_lifecycle.sh"
entry="$ROOT/scripts/kernel/kernel-lifecycle.sh"
module="$ROOT/modules/system/01a_kernel_latest_stable.sh"
doctor="$ROOT/diagnostics/kernel-doctor"
control="$ROOT/control.sh"

for file in "$conf" "$policy" "$lib" "$entry" "$module" "$doctor" "$control"; do
  [[ -s "$file" ]] || { echo "missing kernel lifecycle file: $file" >&2; exit 1; }
done

grep -Fxq 'mode=candidate-certified' "$policy"
grep -Fxq 'candidate_track=latest-stable' "$policy"
grep -Fxq 'certification_required=true' "$policy"
grep -Fxq 'keep_previous_certified=true' "$policy"
grep -Fxq 'keep_fedora_fallback=true' "$policy"
grep -Fxq 'one_shot_test_boot=true' "$policy"
grep -Fxq 'required_suspend_cycles=5' "$policy"
grep -Fq 'KERNEL_REQUIRE_LATEST_STABLE="true"' "$conf"
grep -Fq 'KERNEL_KEEP_FEDORA_FALLBACK="true"' "$conf"
grep -Fq 'Promotion to Golden is governed separately by kernel-lifecycle.policy' "$conf"

grep -Fq 'candidate.env' "$lib"
grep -Fq 'certified.env' "$lib"
grep -Fq 'previous-certified.env' "$lib"
grep -Fq 'kernel_lifecycle_policy_value' "$lib"
grep -Fq 'kernel_lifecycle_require_mutation_gate' "$lib"
grep -Fq 'apply_gate_require_baseline' "$lib"
grep -Fq 'apply_gate_require_backup' "$lib"
grep -Fq 'grub2-reboot' "$lib"
grep -Fq 'diagnostics/final-certification" certify' "$lib"
grep -Fq 'kernel_lifecycle_current_certification_valid' "$lib"
grep -Fq 'workstation_runtime_fingerprint' "$lib"
grep -Fq "certified_state='stale'" "$lib"
grep -Fq 'grubby --set-default' "$lib"
grep -Fq 'newer does not auto-promote' "$doctor"
grep -Fq 'certified marker is stale' "$doctor"
grep -Fq 'candidate is not Golden until explicit certification' "$module"

for action in candidate boot-candidate certify rollback; do
  grep -Fq "$action" "$entry" || { echo "missing lifecycle action: $action" >&2; exit 1; }
  grep -Fq "$action" "$control" || { echo "control.sh does not expose lifecycle action: $action" >&2; exit 1; }
done

grep -Fq 'rollback-fedora' "$control"

if grep -RInE '(dnf|rpm)[[:space:]].*(remove|erase)|rpm[[:space:]]+-e|rm[[:space:]].*/boot/vmlinuz' "$lib" "$entry" "$module"; then
  echo 'kernel lifecycle must never aggressively remove kernels' >&2
  exit 1
fi

# Latest-stable selection must only stage a candidate; certification must remain explicit.
if grep -Fq 'KERNEL_REQUIRE_LATEST_STABLE' "$doctor" || grep -Fq 'KERNEL_REQUIRE_LATEST_STABLE' "$lib"; then
  echo 'legacy latest-stable selector must not drive certification logic' >&2
  exit 1
fi

echo 'kernel candidate/certified lifecycle contract: PASS'

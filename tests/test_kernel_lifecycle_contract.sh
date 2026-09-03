#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

conf="$ROOT/config/kernel.conf"
lib="$ROOT/lib/kernel_lifecycle.sh"
entry="$ROOT/scripts/kernel/kernel-lifecycle.sh"
module="$ROOT/modules/system/01a_kernel_latest_stable.sh"
doctor="$ROOT/diagnostics/kernel-doctor"
control="$ROOT/control.sh"

for file in "$conf" "$lib" "$entry" "$module" "$doctor" "$control"; do
  [[ -s "$file" ]] || { echo "missing kernel lifecycle file: $file" >&2; exit 1; }
done

grep -Fq 'KERNEL_LIFECYCLE_MODE="candidate-certified"' "$conf"
grep -Fq 'KERNEL_CANDIDATE_TRACK_LATEST_STABLE="true"' "$conf"
grep -Fq 'KERNEL_REQUIRE_LATEST_STABLE="false"' "$conf"
grep -Fq 'KERNEL_CERTIFICATION_REQUIRED="true"' "$conf"
grep -Fq 'KERNEL_KEEP_PREVIOUS_CERTIFIED="true"' "$conf"
grep -Fq 'KERNEL_KEEP_FEDORA_FALLBACK="true"' "$conf"
grep -Fq 'KERNEL_ONE_SHOT_TEST_BOOT="true"' "$conf"

grep -Fq 'candidate.env' "$lib"
grep -Fq 'certified.env' "$lib"
grep -Fq 'previous-certified.env' "$lib"
grep -Fq 'kernel_lifecycle_require_mutation_gate' "$lib"
grep -Fq 'apply_gate_require_baseline' "$lib"
grep -Fq 'apply_gate_require_backup' "$lib"
grep -Fq 'grub2-reboot' "$lib"
grep -Fq 'diagnostics/final-certification" certify' "$lib"
grep -Fq 'workstation_runtime_fingerprint' "$lib"
grep -Fq 'grubby --set-default' "$lib"
grep -Fq 'newer does not auto-promote' "$doctor"
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

if grep -Fq 'KERNEL_REQUIRE_LATEST_STABLE="true"' "$conf"; then
  echo 'latest stable must not be synonymous with certified Golden' >&2
  exit 1
fi

echo 'kernel candidate/certified lifecycle contract: PASS'

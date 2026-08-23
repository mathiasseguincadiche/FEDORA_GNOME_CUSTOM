#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
! grep -RInE --exclude-dir=.git --exclude='test_policy.sh' '(i915\.force_probe|xe\.force_probe|selinux=0|enforcing=0|intel_idle\.max_cstate|pcie_aspm=off)' "$ROOT" || { echo 'forbidden stability workaround found' >&2; exit 1; }
grep -Fq 'ALLOW_GPU_PASSTHROUGH="false"' "$ROOT/config/virtualization.conf"
grep -Fq 'ALLOW_THIRD_PARTY_GPU_REPOS="false"' "$ROOT/config/graphics.conf"
grep -Fq 'REQUIRE_HARDWARE_BASELINE_CERTIFIED="true"' "$ROOT/config/baseline.conf"
grep -Fq 'apply_gate_require_baseline' "$ROOT/lib/apply_gate.sh"
grep -Fq 'baseline.preflight|BASELINE|' "$ROOT/manifests/module-plan.conf"
grep -Fq 'system.preflight|SYSTEM|baseline.validation|' "$ROOT/manifests/module-plan.conf"
echo 'policy: PASS'

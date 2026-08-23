#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
! grep -RInE --exclude-dir=.git --exclude='test_policy.sh' '(i915\.force_probe|xe\.force_probe|selinux=0|enforcing=0|intel_idle\.max_cstate|pcie_aspm=off)' "$ROOT" || { echo 'forbidden stability workaround found' >&2; exit 1; }
grep -Fq 'ALLOW_GPU_PASSTHROUGH="false"' "$ROOT/config/virtualization.conf"
grep -Fq 'ALLOW_THIRD_PARTY_GPU_REPOS="false"' "$ROOT/config/graphics.conf"
echo 'policy: PASS'

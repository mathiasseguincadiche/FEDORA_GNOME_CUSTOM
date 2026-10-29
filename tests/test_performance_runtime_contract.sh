#!/usr/bin/env bash
# Performance runtime specification: the owner's policy values, packages,
# module order, release capture and the forbidden blind tunings. Behaviour is
# exercised by test_performance_runtime_behavior.sh.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "performance runtime contract: FAIL: $*" >&2; exit 1; }
policy="$ROOT/config/performance-runtime.policy"
manifest="$ROOT/manifests/packages-performance.txt"
for expected in \
  'mode_default=balanced' \
  'amd_pstate_mode=active' \
  'epp_balanced=balance_performance' \
  'epp_performance=performance' \
  'sched_ext_policy=auto' \
  'sched_ext_enable_by_default=false' \
  'zram_policy=fedora-default' \
  'nvme_policy=benchmark-only' \
  'allow_experimental_io_scheduler=false' \
  'gamemode_dynamic=true'; do
  grep -Fxq "$expected" "$policy" || fail "policy missing $expected"
done
for pkg in scx_rusty zram-generator-defaults gamemode; do grep -Fxq "$pkg" "$manifest" || fail "$pkg missing"; done
for entry in \
  'performance.cpu_power|PERFORMANCE|desktop.lifecycle|modules/performance/50_cpu_power.sh' \
  'performance.sched_ext|PERFORMANCE|performance.cpu_power|modules/performance/51_sched_ext.sh' \
  'performance.zram|PERFORMANCE|performance.sched_ext|modules/performance/52_zram.sh' \
  'performance.gamemode|PERFORMANCE|performance.zram|modules/performance/53_gamemode_policy.sh' \
  'performance.validation|PERFORMANCE|performance.gamemode|modules/performance/59_performance_validation.sh' \
  'desktop.shell_ux|DESKTOP|performance.validation|modules/desktop/28_shell_ux.sh'; do
  grep -Fq "$entry" "$ROOT/manifests/module-plan.conf" || fail "module plan missing $entry"
done

# Certification and release evidence carry the performance contract.
grep -Fq 'performance-doctor" --quiet --certify' "$ROOT/diagnostics/final-certification" || fail 'final certification does not execute performance certification'
grep -Fq 'performance_contract=PASS' "$ROOT/diagnostics/final-certification" || fail 'final certification does not persist performance PASS'
grep -Fq 'performance_policy_sha256' "$ROOT/scripts/release/capture-golden-release.sh" || fail 'Golden release does not hash performance policy'
grep -Fq "name '*.policy'" "$ROOT/lib/evidence.sh" || fail 'versioned policies must participate in effective_config_sha256'

if grep -RInE 'sysctl[[:space:]]+-w|nohz_full|pcie_aspm=off|nvme_core\.default_ps_max_latency_us|adios|bore|kernel.*(cachy|zen|liquorix)|xe\.force_probe|i915\.force_probe' \
  "$ROOT/config/performance-runtime.policy" "$ROOT/modules/performance" "$ROOT/scripts/performance"; then
  fail 'forbidden blind/global tuning found'
fi
if grep -RInE '^[[:space:]]*(gpu_device|nv_core_clock_mhz_offset|nv_mem_clock_mhz_offset|amd_performance_level)[[:space:]]*=' "$ROOT/modules/performance"; then
  fail 'GPU overclocking must not be introduced by performance runtime'
fi
for workflow in fedora-package-preflight fedora-host-pretest; do
  grep -Fq 'packages-performance.txt' "$ROOT/.github/workflows/$workflow.yml" || fail "$workflow missing performance manifest"
done
echo 'performance runtime contract: PASS'

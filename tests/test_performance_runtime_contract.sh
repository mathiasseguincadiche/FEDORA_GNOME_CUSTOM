#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "performance runtime contract: FAIL: $*" >&2; exit 1; }
policy="$ROOT/config/performance-runtime.policy"
lib="$ROOT/lib/performance_runtime.sh"
manifest="$ROOT/manifests/packages-performance.txt"
for file in "$policy" "$lib" "$manifest" \
  "$ROOT/modules/performance/50_cpu_power.sh" \
  "$ROOT/modules/performance/51_sched_ext.sh" \
  "$ROOT/modules/performance/52_zram.sh" \
  "$ROOT/modules/performance/53_gamemode_policy.sh" \
  "$ROOT/modules/performance/59_performance_validation.sh" \
  "$ROOT/diagnostics/performance-doctor" \
  "$ROOT/diagnostics/sched-ext-doctor" \
  "$ROOT/diagnostics/zram-doctor" \
  "$ROOT/diagnostics/nvme-scheduler-doctor" \
  "$ROOT/diagnostics/frametime-doctor" \
  "$ROOT/scripts/performance/profile.sh" \
  "$ROOT/scripts/performance/game-performance.sh" \
  "$ROOT/scripts/performance/nvme-scheduler-benchmark.sh" \
  "$ROOT/docs/PERFORMANCE.md"; do
  [[ -s "$file" ]] || fail "missing $file"
done
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
for pkg in scx-scheds zram-generator-defaults gamemode; do grep -Fxq "$pkg" "$manifest" || fail "$pkg missing"; done
for entry in \
  'performance.cpu_power|PERFORMANCE|desktop.lifecycle|modules/performance/50_cpu_power.sh' \
  'performance.sched_ext|PERFORMANCE|performance.cpu_power|modules/performance/51_sched_ext.sh' \
  'performance.zram|PERFORMANCE|performance.sched_ext|modules/performance/52_zram.sh' \
  'performance.gamemode|PERFORMANCE|performance.zram|modules/performance/53_gamemode_policy.sh' \
  'performance.validation|PERFORMANCE|performance.gamemode|modules/performance/59_performance_validation.sh' \
  'desktop.shell_ux|DESKTOP|performance.validation|modules/desktop/28_shell_ux.sh'; do
  grep -Fq "$entry" "$ROOT/manifests/module-plan.conf" || fail "module plan missing $entry"
done
grep -Fq 'tuned-adm profile' "$ROOT/scripts/performance/profile.sh" || fail 'TuneD profile switch missing'
grep -Fq 'runtime_is_baremetal' "$ROOT/scripts/performance/profile.sh" || fail 'profile mutation must be bare-metal only'
grep -Fq 'gamemoderun' "$ROOT/scripts/performance/game-performance.sh" || fail 'dynamic GameMode wrapper missing'
grep -Fq 'trap restore EXIT INT TERM' "$ROOT/scripts/performance/game-performance.sh" || fail 'profile restore trap missing'
grep -Fq 'CONFIG_SCHED_CLASS_EXT' "$ROOT/diagnostics/sched-ext-doctor" || fail 'sched_ext kernel capability probe missing'
grep -Fq '/sys/kernel/btf/vmlinux' "$ROOT/diagnostics/sched-ext-doctor" || fail 'sched_ext BTF probe missing'
grep -Fq 'timeout --signal=INT' "$ROOT/diagnostics/sched-ext-doctor" || fail 'bounded sched_ext smoke missing'
grep -Fq 'zram-generator-defaults' "$ROOT/diagnostics/zram-doctor" || fail 'zram doctor missing Fedora defaults'
grep -Fq 'CT1000T705SSD3' "$ROOT/scripts/performance/nvme-scheduler-benchmark.sh" || fail 'benchmark must lock to target T705'
grep -Fq 'none mq-deadline' "$ROOT/scripts/performance/nvme-scheduler-benchmark.sh" || fail 'benchmark candidates missing'
grep -Fq 'trap restore EXIT INT TERM' "$ROOT/scripts/performance/nvme-scheduler-benchmark.sh" || fail 'NVMe scheduler restore trap missing'
grep -Fq "('p99',.99)" "$ROOT/diagnostics/frametime-doctor" || fail 'p99 frametime percentile missing'
if grep -RInE 'sysctl[[:space:]]+-w|nohz_full|pcie_aspm=off|nvme_core\.default_ps_max_latency_us|adios|bore|kernel.*(cachy|zen|liquorix)|xe\.force_probe|i915\.force_probe' \
  "$ROOT/config/performance-runtime.policy" "$ROOT/modules/performance" "$ROOT/scripts/performance"; then
  fail 'forbidden blind/global tuning found'
fi
if grep -RInE '^[[:space:]]*(gpu_device|nv_core_clock_mhz_offset|nv_mem_clock_mhz_offset|amd_performance_level)[[:space:]]*=' "$ROOT/modules/performance"; then
  fail 'GPU overclocking must not be introduced by performance runtime'
fi
grep -Fq 'packages-performance.txt' "$ROOT/.github/workflows/fedora-package-preflight.yml" || fail 'package preflight missing performance manifest'
grep -Fq 'packages-performance.txt' "$ROOT/.github/workflows/fedora-host-pretest.yml" || fail 'host pretest missing performance manifest'
grep -Fq 'test_performance_runtime_contract.sh' "$ROOT/.github/workflows/tests.yml" || fail 'tests workflow missing performance contract'
echo 'performance runtime contract: PASS'

#!/usr/bin/env bash
# Performance runtime run for real in a repository copy with a fixture sysfs
# and fake TuneD/systemd/fio: the versioned policy is validated, profile and
# GameMode switches are bare-metal only and always restored, the NVMe scheduler
# benchmark only touches the target T705 and restores its scheduler, the
# sched_ext smoke is bounded, and the certification doctors demand the Golden
# runtime (AMD P-State, boost, tuned-ppd, balanced mode, active zram).
# shellcheck disable=SC2016,SC1090,SC1091,SC2015
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "performance runtime behavior: FAIL: $*" >&2; exit 1; }

fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/home" "$tmp/data"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home" T_LOG="$tmp/calls" T_TMP="$tmp" T_SYS="$tmp/sys"
unset XDG_CONFIG_HOME XDG_STATE_HOME

# Fixture sysfs: Ryzen with AMD P-State active, zram0, the T705 behind /data.
cpu="$T_SYS/devices/system/cpu"
mkdir -p "$cpu/cpufreq/policy0" "$cpu/cpufreq/policy1" "$cpu/amd_pstate" "$T_SYS/block/zram0" \
  "$T_SYS/block/nvme1n1/queue" "$T_SYS/block/nvme1n1/device" "$T_SYS/kernel/sched_ext" "$T_SYS/kernel/btf"
echo amd-pstate-epp > "$cpu/cpufreq/policy0/scaling_driver"
for policy in policy0 policy1; do echo balance_performance > "$cpu/cpufreq/$policy/energy_performance_preference"; done
echo active > "$cpu/amd_pstate/status"; echo 1 > "$cpu/cpufreq/boost"
echo 'lzo-rle [zstd]' > "$T_SYS/block/zram0/comp_algorithm"; echo 8589934592 > "$T_SYS/block/zram0/disksize"
echo 'CT1000T705SSD3                          ' > "$T_SYS/block/nvme1n1/device/model"
touch "$T_SYS/kernel/btf/vmlinux"
for file in lib/performance_runtime.sh diagnostics/zram-doctor diagnostics/sched-ext-doctor scripts/performance/nvme-scheduler-benchmark.sh; do
  sed -i 's|/sys/|$T_SYS/|g' "$fixture/$file"
  grep -Fq '$T_SYS/' "$fixture/$file" || fail "cannot redirect sysfs in $file"
done
cat >> "$fixture/lib/apply_gate.sh" <<'SH'
runtime_environment_detect() { echo "${T_RUNTIME:-baremetal}"; }
SH
cat >> "$fixture/lib/persistent_data.sh" <<'SH'
persistent_data_validate_mount() { [[ "${T_DATA:-valid}" == valid ]]; }
SH
sed -i 's/^sched_ext_smoke_seconds=.*/sched_ext_smoke_seconds=1/' "$fixture/config/performance-runtime.policy"
printf 'EXPECTED_DATA_MOUNT="%s"\n' "$tmp/data" > "$fixture/config/local.conf"
printf '#!/usr/bin/env bash\nexit 0\n' > "$fixture/diagnostics/nvme-scheduler-doctor"

fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
fake sudo 'printf "sudo %s\n" "$*" >> "$T_LOG"; exec "$@"'
fake tuned-adm 'case "$1" in
  active) echo "Current active profile: $(cat "$T_TMP/tuned")" ;;
  profile) printf "%s" "$2" > "$T_TMP/tuned"; printf "tuned %s\n" "$2" >> "$T_LOG" ;;
esac'
fake gamemoderun 'printf "game %s profile=%s\n" "$*" "$(cat "$T_TMP/tuned")" >> "$T_LOG"; exit "${T_GAME_RC:-0}"'
fake systemctl '[[ "$1 $2" == "is-active --quiet" ]] || exit 99; for unit in ${T_INACTIVE:-}; do [[ "$3" != "$unit" ]] || exit 3; done'
fake rpm 'for missing in ${T_MISSING:-}; do [[ "$2" != "$missing" ]] || exit 1; done'
fake swapon '[[ -n "${T_NO_SWAP:-}" ]] || echo "/dev/zram0 partition 8G 0B 100"'
fake findmnt 'echo /dev/nvme1n1p1'
fake lsblk 'echo nvme1n1'
fake fio 'printf "fio %s scheduler=%s\n" "$*" "$(cat "$T_SYS/block/nvme1n1/queue/scheduler")" >> "$T_LOG"
for arg; do case "$arg" in --output=*) out="${arg#*=}" ;; --filename=*) : > "${arg#*=}" ;; esac; done
[[ -z "${T_FIO_RC:-}" ]] || exit "$T_FIO_RC"
echo "{\"jobs\": [{\"read\": {\"iops\": 1000, \"bw\": 4000}, \"write\": {\"iops\": 400, \"bw\": 1600}}]}" > "$out"'
fake scx_rusty 'echo "scx_rusty: ${T_SCX_OUTPUT:-scheduler attached}"; exec sleep 30'
export PATH="$tmp/bin:$PATH"
echo balanced > "$tmp/tuned"
cd "$fixture"

# Versioned policy: the Golden file is valid; unsafe or unknown values are refused.
validate() { (REPO_ROOT="$fixture"; source lib/constants.sh; ui_error() { :; }; source lib/performance_runtime.sh; performance_runtime_validate_policy); }
validate || fail 'Golden performance policy refused'
cp config/performance-runtime.policy "$tmp/policy.ok"
for change in 's/^zram_policy=.*/zram_policy=custom/' 's/^nvme_policy=.*/nvme_policy=auto/' \
  's/^epp_performance=.*/epp_performance=power/' 's/^sched_ext_policy=.*/sched_ext_policy=always/' \
  's/^mode_default=.*/mode_default=turbo/' '$a sysctl_vm_swappiness=10'   's/^tuned_performance_profile=.*/tuned_performance_profile=throughput-performance;reboot/'   's/^gamemode_desired_governor=.*/gamemode_desired_governor=$(id)/'; do
  sed "$change" "$tmp/policy.ok" > config/performance-runtime.policy
  rc=0; validate || rc=$?
  [[ "$rc" != 0 ]] || fail "unsafe performance policy accepted: $change"
done
cp "$tmp/policy.ok" config/performance-runtime.policy

# TuneD profiles: status is read-only, switching is bare-metal only.
profile() { rm -f "$T_LOG"; env "${@:2}" bash scripts/performance/profile.sh "$1" > "$tmp/out" 2>&1; }
profile status && grep -Fxq 'tuned_profile=balanced' "$tmp/out" && grep -Fxq 'epp=balance_performance' "$tmp/out" || fail 'profile status wrong'
[[ ! -e "$T_LOG" ]] || fail 'profile status mutated TuneD'
profile performance && [[ "$(cat "$tmp/tuned")" == throughput-performance ]] && grep -Fxq 'expected_epp=performance' "$tmp/out" \
  || fail 'performance mode did not select the versioned TuneD profile'
profile balanced && [[ "$(cat "$tmp/tuned")" == balanced ]] || fail 'balanced mode not restored'
rc=0; profile performance T_RUNTIME=vm || rc=$?
[[ "$rc" != 0 && "$(cat "$tmp/tuned")" == balanced && ! -e "$T_LOG" ]] || fail 'profile switched outside bare metal'
rc=0; profile turbo || rc=$?; [[ "$rc" != 0 && ! -e "$T_LOG" ]] || fail 'unknown profile accepted'
echo 'mode_default=balanced;rm' >> config/performance-runtime.policy
rc=0; profile performance || rc=$?; [[ "$rc" != 0 && ! -e "$T_LOG" ]] || fail 'profile switched with an unsafe policy'
cp "$tmp/policy.ok" config/performance-runtime.policy

# GameMode wrapper: performance only while the game runs, previous profile always restored.
game() { rm -f "$T_LOG"; env "${@:2}" bash scripts/performance/game-performance.sh "$1" --fullscreen > "$tmp/out" 2>&1; }
game ./game || fail 'game launch failed'
grep -Fxq 'game ./game --fullscreen profile=throughput-performance' "$T_LOG" || fail 'game did not run under GameMode in performance mode'
[[ "$(cat "$tmp/tuned")" == balanced ]] || fail 'previous profile not restored after the game'
rc=0; game ./game T_GAME_RC=3 || rc=$?
[[ "$rc" == 3 && "$(cat "$tmp/tuned")" == balanced ]] || fail "crashed game left the performance profile (rc=$rc)"
rc=0; game ./game T_RUNTIME=vm || rc=$?; [[ "$rc" != 0 && ! -e "$T_LOG" ]] || fail 'GameMode profile used outside bare metal'
mv "$tmp/bin/gamemoderun" "$tmp/gamemoderun.off"
rc=0; game ./game || rc=$?; [[ "$rc" != 0 && ! -e "$T_LOG" ]] || fail 'game launched without gamemoderun'
mv "$tmp/gamemoderun.off" "$tmp/bin/gamemoderun"

# NVMe scheduler benchmark: target T705 only, candidates none/mq-deadline, scheduler restored.
sched="$T_SYS/block/nvme1n1/queue/scheduler"
nvme() { rm -f "$T_LOG"; echo 'none [mq-deadline] kyber bfq' > "$sched"; env "$@" bash scripts/performance/nvme-scheduler-benchmark.sh > "$tmp/out" 2>&1; }
nvme || { cat "$tmp/out" >&2; fail 'NVMe scheduler benchmark failed'; }
[[ "$(grep '^fio ' "$T_LOG" | sed 's/.*scheduler=//' | paste -sd'|')" == 'none|mq-deadline' ]] || fail 'benchmark candidates are not none then mq-deadline'
[[ "$(cat "$sched")" == mq-deadline ]] || fail "scheduler not restored: $(cat "$sched")"
grep -Fxq 'scheduler=none' "$tmp/out" && grep -Fxq 'read_iops=1000.00' "$tmp/out" || fail 'benchmark report missing'
[[ -z "$(find "$tmp/data" -name '.fgc-nvme-scheduler-benchmark.*')" ]] || fail 'benchmark scratch file left on /data'
rc=0; nvme T_FIO_RC=1 || rc=$?
[[ "$rc" != 0 && "$(cat "$sched")" == mq-deadline && -z "$(find "$tmp/data" -name '.fgc-*')" ]] || fail 'failed benchmark did not restore the scheduler'
refused() { local why="$1" rc=0; shift; nvme "$@" || rc=$?; [[ "$rc" != 0 && ! -s "$T_LOG" ]] || fail "NVMe benchmark ran with $why"; }
echo 'Samsung SSD 990 PRO 2TB' > "$T_SYS/block/nvme1n1/device/model"; refused 'a non-target NVMe'
echo 'CT1000T705SSD3' > "$T_SYS/block/nvme1n1/device/model"
refused 'an unproven /data' T_DATA=invalid
refused 'a VM runtime' T_RUNTIME=vm
sed -i 's/^allow_experimental_io_scheduler=.*/allow_experimental_io_scheduler=true/' config/performance-runtime.policy
refused 'experimental I/O schedulers allowed'
cp "$tmp/policy.ok" config/performance-runtime.policy
sed -i 's/^sched_ext_smoke_seconds=.*/sched_ext_smoke_seconds=1/' config/performance-runtime.policy

# sched_ext smoke: bounded run, load failures and non-bare-metal refused.
scx() { rm -f "$T_LOG"; env "$@" bash diagnostics/sched-ext-doctor --smoke > "$tmp/out" 2>&1; }
start="$(date +%s)"; scx || { cat "$tmp/out" >&2; fail 'sched_ext smoke failed'; }
(( $(date +%s) - start < 10 )) || fail 'sched_ext smoke was not bounded'
grep -q '^sudo timeout --signal=INT --kill-after=2s 1s .*scx_rusty$' "$T_LOG" || fail "sched_ext smoke not run under a bounded timeout: $(cat "$T_LOG")"
rc=0; scx T_SCX_OUTPUT='libbpf: failed to load BPF program' || rc=$?; [[ "$rc" != 0 ]] || fail 'sched_ext load failure accepted'
rc=0; scx T_RUNTIME=vm || rc=$?; [[ "$rc" != 0 && ! -e "$T_LOG" ]] || fail 'sched_ext smoke ran outside bare metal'
bash diagnostics/sched-ext-doctor --quiet || fail 'optional sched_ext must not fail without a smoke'

# zram doctor: certification requires an active Fedora zram swap.
zram() { bash diagnostics/zram-doctor "$@" > "$tmp/out" 2>&1; }
zram --certify || fail 'active zram refused'
rc=0; T_NO_SWAP=1 zram --certify || rc=$?; [[ "$rc" != 0 ]] || fail 'certification passed without zram swap'
T_NO_SWAP=1 zram || fail 'missing zram swap must only warn outside certification'
rc=0; T_MISSING=zram-generator-defaults zram || rc=$?; [[ "$rc" != 0 ]] || fail 'zram without Fedora defaults accepted'

# Performance certification: the normal Golden runtime, nothing less.
perf() { bash diagnostics/performance-doctor --quiet "$@" > "$tmp/out" 2>&1; }
perf --certify || { bash diagnostics/performance-doctor --certify >&2 || true; fail 'Golden runtime refused'; }
certify_refuses() { local why="$1" rc=0; shift; env "$@" bash diagnostics/performance-doctor --quiet --certify > /dev/null 2>&1 || rc=$?; [[ "$rc" != 0 ]] || fail "certification accepted $why"; }
certify_refuses 'an inactive tuned-ppd' T_INACTIVE=tuned-ppd.service
certify_refuses 'an inactive TuneD' T_INACTIVE=tuned.service
certify_refuses 'no zram swap' T_NO_SWAP=1
T_INACTIVE=tuned-ppd.service perf || fail 'inactive tuned-ppd must only warn outside certification'
echo 0 > "$cpu/cpufreq/boost"; certify_refuses 'disabled boost'; perf || fail 'boost must only warn outside certification'; echo 1 > "$cpu/cpufreq/boost"
# The performance profile with its matching EPP is consistent, but not the Golden mode.
echo throughput-performance > "$tmp/tuned"
for policy in policy0 policy1; do echo performance > "$cpu/cpufreq/$policy/energy_performance_preference"; done
perf || fail 'consistent performance mode refused outside certification'
certify_refuses 'the performance profile'
echo balanced > "$tmp/tuned"
for policy in policy0 policy1; do echo balance_performance > "$cpu/cpufreq/$policy/energy_performance_preference"; done
for policy in policy0 policy1; do echo power > "$cpu/cpufreq/$policy/energy_performance_preference"; done
certify_refuses 'an EPP outside the balanced mode'
for policy in policy0 policy1; do echo balance_performance > "$cpu/cpufreq/$policy/energy_performance_preference"; done
echo passive > "$cpu/amd_pstate/status"; certify_refuses 'AMD P-State passive'; echo active > "$cpu/amd_pstate/status"
echo acpi-cpufreq > "$cpu/cpufreq/policy0/scaling_driver"; rc=0; perf || rc=$?; [[ "$rc" != 0 ]] || fail 'acpi-cpufreq accepted while AMD P-State is required'
echo amd-pstate-epp > "$cpu/cpufreq/policy0/scaling_driver"
perf --certify || fail 'restored runtime refused'

echo 'performance runtime behavior: PASS'

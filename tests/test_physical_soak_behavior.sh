#!/usr/bin/env bash
# Fixtures exercise refusal/cleanup paths; they never certify physical hardware.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/lib/physical_certification.sh"
for kind in cpu memory gpu; do
  case "$kind" in cpu) minimum=1800;; memory) minimum=3600;; gpu) minimum=900;; esac
  physical_soak_parameters_valid "$kind" "$minimum" 1
  physical_soak_parameters_valid "$kind" 86400 8
  for seconds in 0 1 "$((minimum-1))" 86401 -1 0900 999999999999999999999 not-a-number; do
    if physical_soak_parameters_valid "$kind" "$seconds" 1; then echo "accepted unsafe $kind duration $seconds" >&2; exit 1; fi
  done
  for workers in 0 9 -1 999999999999999999999; do
    if physical_soak_parameters_valid "$kind" "$minimum" "$workers"; then exit 1; fi
  done
  physical_soak_evidence_detail_valid "$kind" "qualification_policy=2 seconds=$minimum elapsed_seconds=$minimum instances=1"
  for detail in \
    "seconds=$minimum elapsed_seconds=$minimum instances=1" \
    "qualification_policy=2 seconds=$minimum elapsed_seconds=$((minimum-1)) instances=1" \
    "qualification_policy=2 seconds=$minimum seconds=$minimum elapsed_seconds=$minimum instances=1" \
    "qualification_policy=2 seconds=0 elapsed_seconds=$minimum instances=1"; do
    if physical_soak_evidence_detail_valid "$kind" "$detail"; then echo 'accepted missing/short/ambiguous proof' >&2; exit 1; fi
  done
done
physical_cpu_temp_millic() { printf '%s\n' "$sample"; }
sample=45000
[[ "$(physical_cpu_sample_checked 95000)" == 45000 ]]
for sample in 0 invalid 95000 96000; do
  if physical_cpu_sample_checked 95000 >/dev/null 2>&1; then exit 1; fi
done
sample=45000
if physical_cpu_sample_checked 96000 >/dev/null 2>&1; then exit 1; fi
physical_cpu_temp_millic() { return 1; }
if physical_cpu_sample_checked 95000 >/dev/null 2>&1; then exit 1; fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/lib" "$tmp/diagnostics" "$tmp/bin" "$tmp/reports"
cp "$ROOT/diagnostics/baseline-doctor" "$ROOT/diagnostics/physical-runtime-doctor" "$tmp/diagnostics/"
printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/diagnostics/graphics-doctor"
chmod +x "$tmp/diagnostics/graphics-doctor"
export SOAK_TEST_ROOT="$ROOT" SOAK_TEST_TMP="$tmp"
cat >"$tmp/lib/bootstrap.sh" <<'STUB'
source "$SOAK_TEST_ROOT/lib/physical_certification.sh"
engine_bootstrap() { :; }
runtime_is_baremetal() { [[ "${SOAK_TEST_RUNTIME:-baremetal}" == baremetal ]]; }
runtime_environment() { printf '%s\n' "${SOAK_TEST_RUNTIME:-baremetal}"; }
ui_error() { echo "$*" >&2; }
ui_check() { :; }
ui_meta() { :; }
ui_banner() { :; }
command_exists() { command -v "$1" >/dev/null; }
lsmod() { echo nct6683; }
hardware_platform_validate_cpu_power() { :; }
kernel_journal_require_clean() { :; }
baseline_write_evidence() { echo PASS >"$SOAK_TEST_TMP/evidence"; }
physical_runtime_write_evidence() { echo PASS >"$SOAK_TEST_TMP/evidence"; }
physical_cpu_temp_millic() {
  local count=0
  [[ ! -f "$SOAK_TEST_TMP/samples" ]] || count="$(cat "$SOAK_TEST_TMP/samples")"
  count=$((count+1)); echo "$count" >"$SOAK_TEST_TMP/samples"
  if (( count == 1 )) || [[ "$SOAK_TEST_MODE" == early ]]; then echo 45000;
  elif [[ "$SOAK_TEST_MODE" == missing ]]; then return 1;
  else echo 95000; fi
}
sudo() { if [[ "$1" == dmidecode ]]; then echo 'Configured Memory Speed: 5600 MT/s'; else return 1; fi; }
EXIT_SECURITY_BLOCK=50
EXIT_CONFIG_FAILED=10
EXIT_PRECHECK_FAILED=20
EXIT_POSTCHECK_FAILED=40
EXIT_USAGE=2
REPORT_ROOT="$SOAK_TEST_TMP/reports"
RUN_ID=test
STUB
cat >"$tmp/bin/stress-ng" <<'STUB'
#!/usr/bin/env bash
echo "$$" >"$SOAK_TEST_TMP/workload.pid"
if [[ "$SOAK_TEST_MODE" == early ]]; then exit 0; fi
sleep 60 &
echo "$!" >"$SOAK_TEST_TMP/worker.pid"
wait
STUB
printf '#!/usr/bin/env bash\nexit 0\n' >"$tmp/bin/vkcube-wayland"
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" XDG_SESSION_TYPE=wayland SOAK_TEST_MODE=early

expect_failure() {
  local expected="$1" result=0
  shift
  rm -f "$tmp/evidence" "$tmp/samples" "$tmp/workload.pid" "$tmp/worker.pid"
  "$@" >"$tmp/output" 2>&1 || result=$?
  [[ "$result" == "$expected" && ! -e "$tmp/evidence" ]] || { cat "$tmp/output" >&2; echo "unexpected refusal rc=$result expected=$expected" >&2; exit 1; }
}
expect_failure 10 env GPU_SOAK_INSTANCES=0 bash "$tmp/diagnostics/physical-runtime-doctor" gpu-soak
expect_failure 10 env GPU_SOAK_SECONDS=1 bash "$tmp/diagnostics/physical-runtime-doctor" gpu-soak
expect_failure 10 env BASELINE_CPU_SOAK_SECONDS=1 bash "$tmp/diagnostics/baseline-doctor" run-cpu-soak
expect_failure 10 env BASELINE_MEMORY_TEST_SECONDS=1 bash "$tmp/diagnostics/baseline-doctor" run-memory-test 5600
expect_failure 40 bash "$tmp/diagnostics/physical-runtime-doctor" gpu-soak
expect_failure 40 bash "$tmp/diagnostics/baseline-doctor" run-cpu-soak
expect_failure 40 bash "$tmp/diagnostics/baseline-doctor" run-memory-test 5600
expect_failure 50 env SOAK_TEST_RUNTIME=kvm bash "$tmp/diagnostics/physical-runtime-doctor" gpu-soak

assert_stopped() {
  local file pid state
  for file in "$tmp/workload.pid" "$tmp/worker.pid"; do
    [[ -f "$file" ]] || continue
    pid="$(cat "$file")"
    state="$(ps -o stat= -p "$pid" 2>/dev/null || true)"
    [[ -z "$state" || "$state" == Z* ]] || { echo "workload left alive: $pid $state" >&2; exit 1; }
  done
}
for SOAK_TEST_MODE in overheat missing; do
  export SOAK_TEST_MODE
  expect_failure 40 bash "$tmp/diagnostics/baseline-doctor" run-cpu-soak
  assert_stopped
done
echo 'Physical soak refusal/cleanup: PASS (fixture tests; hardware remains unqualified)'

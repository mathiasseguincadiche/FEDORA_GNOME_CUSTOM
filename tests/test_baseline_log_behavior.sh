#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/modules/baseline/03_cpu_stability.sh"
source "$ROOT/modules/baseline/04_nvme_health.sh"
EXIT_POSTCHECK_FAILED=40
command_exists() { command -v "$1" >/dev/null; }
log_info() { :; }
baseline_nvme_model_count() { printf '2\n'; }
lscpu() { printf 'AMD Ryzen 7 7700\nVirtualization: AMD-V\n'; }
journalctl() {
  [[ "${journal_failure:-false}" != true ]] || return 1
  printf '%s\n' "${journal_message:-normal boot}"
  # Larger than the pipe buffer: the previous early grep could miss errors.
  python3 -c 'print("normal kernel log line\n" * 10000)'
}
for module in baseline_cpu_stability baseline_nvme_health; do
  journal_failure=false
  journal_message='normal boot'
  "${module}_postcheck"
  journal_failure=true
  rc=0; "${module}_postcheck" || rc=$?
  [[ "$rc" == 40 ]]
  journal_failure=false
  case "$module" in
    baseline_cpu_stability) journal_message='MCE: Hardware Error' ;;
    baseline_nvme_health) journal_message='nvme0: I/O error' ;;
  esac
  rc=0; "${module}_postcheck" || rc=$?
  [[ "$rc" == 40 ]]
done
echo 'baseline log behavior: PASS'

#!/usr/bin/env bash
set -Eeuo pipefail
baseline_cpu_stability_precheck() { command_exists lscpu; }
baseline_cpu_stability_plan() { echo 'Validate Ryzen identity, AMD-V and inspect the current kernel for MCE/thermal failures; no governor or C-State tuning.'; }
baseline_cpu_stability_apply() { log_info BASELINE 'read-only CPU stability check'; }
baseline_cpu_stability_postcheck() {
  local cpu_info
  cpu_info="$(LC_ALL=C lscpu)" || return "$EXIT_POSTCHECK_FAILED"
  grep -Fq "${EXPECTED_CPU:-AMD Ryzen 7 7700}" <<< "$cpu_info" || return "$EXIT_POSTCHECK_FAILED"
  grep -Eq 'Virtualization:[[:space:]]+AMD-V|AMD-V' <<< "$cpu_info" || return "$EXIT_POSTCHECK_FAILED"
  # Drain the producer before matching: grep -q in a pipe can SIGPIPE
  # journalctl and make a real error look absent under pipefail + negation.
  local kernel_log
  command_exists journalctl || return "$EXIT_POSTCHECK_FAILED"
  kernel_log="$(journalctl -k -b --no-pager 2>/dev/null)" || return "$EXIT_POSTCHECK_FAILED"
  if grep -Eqi 'MCE:.*Hardware Error|Machine Check|thermal.*critical' <<< "$kernel_log"; then
    return "$EXIT_POSTCHECK_FAILED"
  fi
}

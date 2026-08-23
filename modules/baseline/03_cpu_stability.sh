#!/usr/bin/env bash
set -Eeuo pipefail
baseline_cpu_stability_precheck() { command_exists lscpu; }
baseline_cpu_stability_plan() { echo 'Validate Ryzen identity, AMD-V and inspect the current kernel for MCE/thermal failures; no governor or C-State tuning.'; }
baseline_cpu_stability_apply() { log_info BASELINE 'read-only CPU stability check'; }
baseline_cpu_stability_postcheck() {
  lscpu | grep -Fq "${EXPECTED_CPU:-AMD Ryzen 7 7700}" || return "$EXIT_POSTCHECK_FAILED"
  lscpu | grep -Eq 'Virtualization:[[:space:]]+AMD-V|AMD-V' || return "$EXIT_POSTCHECK_FAILED"
  if command_exists journalctl; then
    ! journalctl -k -b --no-pager 2>/dev/null | grep -Eqi 'MCE:.*Hardware Error|Machine Check|thermal.*critical' || return "$EXIT_POSTCHECK_FAILED"
  fi
}

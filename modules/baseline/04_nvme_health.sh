#!/usr/bin/env bash
set -Eeuo pipefail
baseline_nvme_health_precheck() { [[ -d /sys/class/nvme ]]; }
baseline_nvme_health_plan() { echo 'Validate both Crucial T705 devices from sysfs and inspect kernel NVMe/PCIe fatal errors; extended SMART data is collected later by storage-doctor when nvme-cli is present.'; }
baseline_nvme_health_apply() { log_info BASELINE 'read-only NVMe health inventory'; }
baseline_nvme_health_postcheck() {
  local count
  count="$(baseline_nvme_model_count)"
  (( count >= ${EXPECTED_NVME_COUNT:-2} )) || return "$EXIT_POSTCHECK_FAILED"
  log_info BASELINE "expected-nvme-count=$count"
  # Drain the producer before matching: grep -q in a pipe can SIGPIPE
  # journalctl and make a real error look absent under pipefail + negation.
  local kernel_log
  command_exists journalctl || return "$EXIT_POSTCHECK_FAILED"
  kernel_log="$(journalctl -k -b --no-pager 2>/dev/null)" || return "$EXIT_POSTCHECK_FAILED"
  if grep -Eqi 'nvme.*(I/O error|reset controller|device not ready)|PCIe Bus Error: severity=Uncorrected' <<< "$kernel_log"; then
    return "$EXIT_POSTCHECK_FAILED"
  fi
}

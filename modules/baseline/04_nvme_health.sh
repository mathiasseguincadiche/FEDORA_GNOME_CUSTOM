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
  if command_exists journalctl; then
    ! journalctl -k -b --no-pager 2>/dev/null | grep -Eqi 'nvme.*(I/O error|reset controller|device not ready)|PCIe Bus Error: severity=Uncorrected' || return "$EXIT_POSTCHECK_FAILED"
  fi
}

#!/usr/bin/env bash
set -Eeuo pipefail
baseline_gpu_precheck() { return 0; }
baseline_gpu_plan() { echo 'Validate Intel Arc B580 PCI identity and xe binding directly from sysfs; no third-party GPU repository, force_probe or experimental kernel argument.'; }
baseline_gpu_apply() { log_info BASELINE 'read-only GPU baseline'; }
baseline_gpu_postcheck() {
  local gpu driver
  gpu="$(baseline_find_expected_gpu)" || return "$EXIT_POSTCHECK_FAILED"
  driver="${gpu#*|}"
  [[ "$driver" == "${EXPECTED_GPU_KERNEL_DRIVER:-xe}" ]] || return "$EXIT_POSTCHECK_FAILED"
  log_info BASELINE "gpu=$gpu"
}

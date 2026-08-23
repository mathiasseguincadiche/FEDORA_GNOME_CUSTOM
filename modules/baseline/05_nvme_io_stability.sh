#!/usr/bin/env bash
set -Eeuo pipefail
baseline_nvme_io_precheck() { return 0; }
baseline_nvme_io_plan() { echo 'Require explicit PASS evidence from the controlled sustained-I/O test. The orchestrator never runs a destructive benchmark automatically.'; }
baseline_nvme_io_apply() { log_info BASELINE 'NVMe I/O stress remains operator-controlled'; }
baseline_nvme_io_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  baseline_evidence_valid nvme-io || return "$EXIT_POSTCHECK_FAILED"
}

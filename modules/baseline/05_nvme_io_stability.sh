#!/usr/bin/env bash
set -Eeuo pipefail
baseline_nvme_io_precheck() { return 0; }
baseline_nvme_io_plan() { echo 'Require automated fio PASS evidence on both root and dedicated /data T705 filesystems. No destructive raw-device benchmark is ever run.'; }
baseline_nvme_io_apply() { log_info BASELINE 'NVMe certification is operator-triggered through baseline-doctor run-nvme-test root/data'; }
baseline_nvme_io_postcheck() { is_true "${DRY_RUN:-true}" && return 0; baseline_evidence_valid nvme-root || return "$EXIT_POSTCHECK_FAILED"; baseline_evidence_valid nvme-data || return "$EXIT_POSTCHECK_FAILED"; }

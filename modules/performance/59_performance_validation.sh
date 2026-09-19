#!/usr/bin/env bash
set -Eeuo pipefail
performance_validation_precheck() { return 0; }
performance_validation_plan() { echo 'Validate Fedora-Cachy runtime performance policy without requiring experimental sched_ext or NVMe scheduler mutations.'; }
performance_validation_apply() { return 0; }
performance_validation_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  "$REPO_ROOT/diagnostics/performance-doctor" --quiet --core
}

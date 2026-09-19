#!/usr/bin/env bash
set -Eeuo pipefail
source "$REPO_ROOT/lib/performance_runtime.sh"

performance_zram_precheck() { [[ "$(performance_policy_get zram_policy)" == fedora-default ]]; }
performance_zram_plan() { echo 'Preserve Fedora swap-on-zram defaults; add observability only and never impose a custom size, compression algorithm or global swappiness value.'; }
performance_zram_apply() {
  is_true "${DRY_RUN:-true}" && return 0
  run_mutating PERFORMANCE sudo systemctl daemon-reload || return "$EXIT_APPLY_FAILED"
}
performance_zram_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  "$REPO_ROOT/diagnostics/zram-doctor" --quiet
}

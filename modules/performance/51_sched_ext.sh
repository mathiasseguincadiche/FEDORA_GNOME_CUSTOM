#!/usr/bin/env bash
set -Eeuo pipefail
source "$REPO_ROOT/lib/performance_runtime.sh"

performance_sched_ext_precheck() { performance_runtime_validate_policy; }
performance_sched_ext_plan() { echo 'Keep sched_ext optional/fail-safe: install Fedora scheduler tooling, never enable an SCX scheduler globally, and require an explicit bare-metal smoke test before use.'; }
performance_sched_ext_apply() {
  if [[ "$(performance_policy_get sched_ext_enable_by_default)" == true ]]; then
    log_error PERFORMANCE 'sched_ext_enable_by_default=true is intentionally unsupported by the Golden profile'
    return "$EXIT_CONFIG_FAILED"
  fi
  return 0
}
performance_sched_ext_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  "$REPO_ROOT/diagnostics/sched-ext-doctor" --quiet
}

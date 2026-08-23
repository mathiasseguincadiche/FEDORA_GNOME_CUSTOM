#!/usr/bin/env bash
set -Eeuo pipefail
baseline_suspend_resume_precheck() { [[ -r /sys/power/mem_sleep ]]; }
baseline_suspend_resume_plan() { echo 'Require at least the configured number of successful suspend/resume evidence cycles; no automatic switch between s2idle and deep.'; }
baseline_suspend_resume_apply() { log_info BASELINE "mem_sleep=$(cat /sys/power/mem_sleep)"; }
baseline_suspend_resume_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  local count
  count="$(baseline_suspend_pass_count)"
  (( count >= ${BASELINE_MIN_SUSPEND_CYCLES:-5} )) || return "$EXIT_POSTCHECK_FAILED"
  log_info BASELINE "suspend-cycles-pass=$count"
}

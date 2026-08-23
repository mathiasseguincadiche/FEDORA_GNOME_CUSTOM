#!/usr/bin/env bash
set -Eeuo pipefail
baseline_display_precheck() { return 0; }
baseline_display_plan() { echo 'Record Wayland/display baseline and DRM connector state without forcing VRR, HDR, refresh rate or experimental Mutter settings.'; }
baseline_display_apply() { log_info BASELINE 'read-only display baseline'; }
baseline_display_postcheck() {
  if [[ -n "${XDG_SESSION_TYPE:-}" ]]; then
    [[ "${XDG_SESSION_TYPE}" == wayland ]] || return "$EXIT_POSTCHECK_FAILED"
  else
    log_warn BASELINE 'no graphical session detected; runtime 1440p/240Hz validation deferred'
  fi
  local connector
  for connector in /sys/class/drm/card*-*/status; do
    [[ -r "$connector" ]] || continue
    if [[ "$(<"$connector")" == connected ]]; then
      log_info BASELINE "connected=${connector%/status}"
    fi
  done
}

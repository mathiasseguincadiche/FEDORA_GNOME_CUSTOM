#!/usr/bin/env bash
set -Eeuo pipefail
hardware_display_precheck() { :; }
hardware_display_plan() { echo 'Treat GNOME Wayland as canonical; inventory Mutter DisplayConfig/EDID and expected 2560x1440@240 without forcing experimental display flags or font rendering.'; }
hardware_display_apply() { :; }
hardware_display_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  if [[ -n "${XDG_SESSION_TYPE:-}" ]] && is_true "${REQUIRE_WAYLAND:-true}"; then [[ "$XDG_SESSION_TYPE" == wayland ]] || return "$EXIT_POSTCHECK_FAILED"; fi
  if command_exists gdbus && [[ "${XDG_SESSION_TYPE:-}" == wayland ]]; then
    gdbus call --session --dest org.gnome.Mutter.DisplayConfig --object-path /org/gnome/Mutter/DisplayConfig --method org.gnome.Mutter.DisplayConfig.GetCurrentState > "$REPORT_ROOT/$RUN_ID-mutter-display-state.txt" 2>&1 || log_warn HARDWARE 'Mutter DisplayConfig probe failed'
  fi
}

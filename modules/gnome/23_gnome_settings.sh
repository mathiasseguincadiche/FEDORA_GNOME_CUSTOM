#!/usr/bin/env bash
set -Eeuo pipefail

gnome_settings_precheck() {
  is_true "${GNOME_WINDOW_BUTTONS_ENABLED:-true}" || return 0
  command_exists gsettings || return "$EXIT_PRECHECK_FAILED"
  gsettings list-keys org.gnome.desktop.wm.preferences 2>/dev/null | grep -Fxq 'button-layout' || {
    log_error GNOME 'GNOME window-manager button-layout key is unavailable'
    return "$EXIT_PRECHECK_FAILED"
  }
  [[ "${GNOME_WINDOW_BUTTON_LAYOUT:-:minimize,maximize,close}" == ':minimize,maximize,close' ]] || {
    log_error GNOME 'Golden workstation requires minimize,maximize,close window controls on the right'
    return "$EXIT_CONFIG_FAILED"
  }
}

gnome_settings_plan() {
  echo 'Preserve upstream font antialiasing/hinting and Mutter experimental defaults; explicitly expose minimize, maximize and close window controls on the right.'
}

gnome_settings_apply() {
  is_true "${GNOME_WINDOW_BUTTONS_ENABLED:-true}" || return 0
  run_mutating GNOME gsettings set org.gnome.desktop.wm.preferences button-layout "${GNOME_WINDOW_BUTTON_LAYOUT:-:minimize,maximize,close}" || return "$EXIT_APPLY_FAILED"
}

gnome_settings_postcheck() {
  local layout actual report
  is_true "${DRY_RUN:-true}" && return 0
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
    report="$REPORT_ROOT/$RUN_ID-gnome-font-settings.txt"
    gsettings get org.gnome.desktop.interface font-name > "$report" 2>&1 || true
    gsettings get org.gnome.desktop.interface font-antialiasing >> "$report" 2>&1 || true
    gsettings get org.gnome.desktop.interface font-hinting >> "$report" 2>&1 || true

    if is_true "${GNOME_WINDOW_BUTTONS_ENABLED:-true}"; then
      layout="${GNOME_WINDOW_BUTTON_LAYOUT:-:minimize,maximize,close}"
      actual="$(gsettings get org.gnome.desktop.wm.preferences button-layout 2>/dev/null || true)"
      printf 'window-button-layout=%s\n' "$actual" >> "$report"
      [[ "$actual" == "'$layout'" ]] || {
        log_error GNOME "window button layout mismatch: expected '$layout', got ${actual:-unavailable}"
        return "$EXIT_POSTCHECK_FAILED"
      }
    fi
  fi
}

#!/usr/bin/env bash
set -Eeuo pipefail
gnome_settings_precheck() { :; }
gnome_settings_plan() { echo 'Preserve upstream font antialiasing/hinting and Mutter experimental defaults. Do not force scaling, VRR, HDR, subpixel rendering or custom font rasterization.'; }
gnome_settings_apply() { :; }
gnome_settings_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
    gsettings get org.gnome.desktop.interface font-name > "$REPORT_ROOT/$RUN_ID-gnome-font-settings.txt" 2>&1 || true
    gsettings get org.gnome.desktop.interface font-antialiasing >> "$REPORT_ROOT/$RUN_ID-gnome-font-settings.txt" 2>&1 || true
    gsettings get org.gnome.desktop.interface font-hinting >> "$REPORT_ROOT/$RUN_ID-gnome-font-settings.txt" 2>&1 || true
  fi
}

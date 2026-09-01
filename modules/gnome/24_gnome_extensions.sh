#!/usr/bin/env bash
set -Eeuo pipefail

gnome_extensions_precheck() {
  is_true "${ENABLE_GNOME_EXTENSIONS:-false}" || return 0
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"

  if is_true "${ENABLE_DASH_TO_DOCK:-false}"; then
    [[ "${DASH_TO_DOCK_PACKAGE:-}" == "gnome-shell-extension-dash-to-dock" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${DASH_TO_DOCK_UUID:-}" == "dash-to-dock@micxgx.gmail.com" ]] || return "$EXIT_PRECHECK_FAILED"
  fi

  if is_true "${ENABLE_BLUR_MY_SHELL:-false}"; then
    [[ "${BLUR_MY_SHELL_PACKAGE:-}" == "gnome-shell-extension-blur-my-shell" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${BLUR_MY_SHELL_UUID:-}" == "blur-my-shell@aunetx" ]] || return "$EXIT_PRECHECK_FAILED"
  fi

  if is_true "${ENABLE_APPINDICATOR:-false}"; then
    [[ "${APPINDICATOR_PACKAGE:-}" == "gnome-shell-extension-appindicator" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${APPINDICATOR_UUID:-}" == "appindicatorsupport@rgcjonas.gmail.com" ]] || return "$EXIT_PRECHECK_FAILED"
  fi

  if is_true "${ENABLE_DESKTOP_ICONS_NG:-false}"; then
    [[ "${DING_UUID:-}" == "ding@rastersoft.com" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${DING_SOURCE_URL:-}" == "https://extensions.gnome.org/review/download/74408.shell-extension.zip" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${DING_REVIEW_ID:-}" == "74408" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${DING_VERSION:-}" == "95" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${DING_SHELL_VERSION:-}" == "50" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${DING_SCHEMA:-}" == "org.gnome.shell.extensions.ding" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${DING_DESKTOP_DIR_NAME:-}" == "Bureau" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${DING_SHOW_TRASH:-}" == "true" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${DING_SHOW_HOME:-}" == "false" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${DING_SHOW_VOLUMES:-}" == "false" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${DING_SHOW_NETWORK_VOLUMES:-}" == "false" ]] || return "$EXIT_PRECHECK_FAILED"
  fi

  if is_true "${ENABLE_SHOW_DESKTOP_PLUS:-false}"; then
    [[ "${SHOW_DESKTOP_PLUS_UUID:-}" == "show-desktop-plus@attentivecoder" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${SHOW_DESKTOP_PLUS_SOURCE_URL:-}" == "https://extensions.gnome.org/review/download/70326.shell-extension.zip" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${SHOW_DESKTOP_PLUS_REVIEW_ID:-}" == "70326" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${SHOW_DESKTOP_PLUS_VERSION:-}" == "8" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${SHOW_DESKTOP_PLUS_SHELL_VERSION:-}" == "50" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${SHOW_DESKTOP_PLUS_SCHEMA:-}" == "org.gnome.shell.extensions.show-desktop-plus" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${SHOW_DESKTOP_PLUS_BUTTON_POSITION:-}" == "left-end" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${SHOW_DESKTOP_PLUS_LEFT_CLICK_ACTION:-}" == "toggle-desktop" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${SHOW_DESKTOP_PLUS_ENABLE_HOTKEY:-}" == "true" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${SHOW_DESKTOP_PLUS_HOTKEY:-}" == "<Super>d" ]] || return "$EXIT_PRECHECK_FAILED"
  fi

  if is_true "${ENABLE_JUST_PERFECTION:-false}"; then
    log_error GNOME 'Just Perfection is explicitly excluded by the workstation desktop policy'
    return "$EXIT_PRECHECK_FAILED"
  fi
}

gnome_extensions_plan() {
  cat <<'EOF'
GNOME EXTENSIONS PLAN:
- Fedora 44 / GNOME 50 remains the desktop reference
- Dash to Dock is enabled from the official Fedora RPM
- AppIndicator is enabled from the official Fedora RPM for functional tray compatibility
- Desktop Icons NG (DING) v95 is installed from the exact GNOME-reviewed artifact 74408; XDG Desktop is ~/Bureau, Trash is visible, Home/external/network volumes are hidden
- Show Desktop Plus v8 is installed from the exact GNOME-reviewed artifact 70326 and configured as a top-left desktop toggle with Super+D
- Blur My Shell stays disabled by default for 240 Hz/resume stability
- Extension Manager is installed from Flathub as the administration UI
- Just Perfection and Dash to Panel remain outside the Golden profile
EOF
}

gnome_extension_enable_checked() {
  local label="$1" uuid="$2"
  command_exists gnome-extensions || { log_error GNOME 'gnome-extensions command unavailable'; return "$EXIT_APPLY_FAILED"; }
  if ! gnome-extensions list 2>/dev/null | grep -Fxq "$uuid"; then
    log_error GNOME "$label is installed but the running GNOME session does not see it; log out/in and rerun APPLY"
    return "$EXIT_APPLY_FAILED"
  fi
  if ! gnome-extensions info "$uuid" 2>/dev/null | grep -Fq 'State: ENABLED'; then
    run_mutating GNOME gnome-extensions enable "$uuid" || return "$EXIT_APPLY_FAILED"
  fi
}

gnome_ding_schema_dir() {
  printf '%s/%s/schemas' "${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions" "${DING_UUID:-ding@rastersoft.com}"
}

gnome_ding_settings_apply() {
  local schema="${DING_SCHEMA:-org.gnome.shell.extensions.ding}"
  local schema_dir desktop_dir
  schema_dir="$(gnome_ding_schema_dir)"
  desktop_dir="$HOME/${DING_DESKTOP_DIR_NAME:-Bureau}"
  run_mutating GNOME mkdir -p "$desktop_dir" || return "$EXIT_APPLY_FAILED"
  run_mutating GNOME xdg-user-dirs-update --set DESKTOP "$desktop_dir" || return "$EXIT_APPLY_FAILED"
  run_mutating GNOME gsettings --schemadir "$schema_dir" set "$schema" show-trash "${DING_SHOW_TRASH:-true}" || return "$EXIT_APPLY_FAILED"
  run_mutating GNOME gsettings --schemadir "$schema_dir" set "$schema" show-home "${DING_SHOW_HOME:-false}" || return "$EXIT_APPLY_FAILED"
  run_mutating GNOME gsettings --schemadir "$schema_dir" set "$schema" show-volumes "${DING_SHOW_VOLUMES:-false}" || return "$EXIT_APPLY_FAILED"
  run_mutating GNOME gsettings --schemadir "$schema_dir" set "$schema" show-network-volumes "${DING_SHOW_NETWORK_VOLUMES:-false}" || return "$EXIT_APPLY_FAILED"
}

gnome_show_desktop_plus_schema_dir() {
  printf '%s/%s/schemas' "${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions" "${SHOW_DESKTOP_PLUS_UUID:-show-desktop-plus@attentivecoder}"
}

gnome_show_desktop_plus_settings_apply() {
  local schema="${SHOW_DESKTOP_PLUS_SCHEMA:-org.gnome.shell.extensions.show-desktop-plus}"
  local schema_dir
  schema_dir="$(gnome_show_desktop_plus_schema_dir)"
  local position="'${SHOW_DESKTOP_PLUS_BUTTON_POSITION:-left-end}'"
  local left_action="'${SHOW_DESKTOP_PLUS_LEFT_CLICK_ACTION:-toggle-desktop}'"
  local middle_action="'${SHOW_DESKTOP_PLUS_MIDDLE_CLICK_ACTION:-hide-focused}'"
  local icon_style="'${SHOW_DESKTOP_PLUS_ICON_STYLE:-desktop}'"
  local hotkey="['${SHOW_DESKTOP_PLUS_HOTKEY:-<Super>d}']"
  run_mutating GNOME gsettings --schemadir "$schema_dir" set "$schema" button-position "$position" || return "$EXIT_APPLY_FAILED"
  run_mutating GNOME gsettings --schemadir "$schema_dir" set "$schema" left-click-action "$left_action" || return "$EXIT_APPLY_FAILED"
  run_mutating GNOME gsettings --schemadir "$schema_dir" set "$schema" middle-click-action "$middle_action" || return "$EXIT_APPLY_FAILED"
  run_mutating GNOME gsettings --schemadir "$schema_dir" set "$schema" current-monitor-only "${SHOW_DESKTOP_PLUS_CURRENT_MONITOR_ONLY:-false}" || return "$EXIT_APPLY_FAILED"
  run_mutating GNOME gsettings --schemadir "$schema_dir" set "$schema" enable-hotkey "${SHOW_DESKTOP_PLUS_ENABLE_HOTKEY:-true}" || return "$EXIT_APPLY_FAILED"
  run_mutating GNOME gsettings --schemadir "$schema_dir" set "$schema" show-desktop-hotkey "$hotkey" || return "$EXIT_APPLY_FAILED"
  run_mutating GNOME gsettings --schemadir "$schema_dir" set "$schema" icon-style "$icon_style" || return "$EXIT_APPLY_FAILED"
  run_mutating GNOME gsettings --schemadir "$schema_dir" set "$schema" show-hidden-count "${SHOW_DESKTOP_PLUS_SHOW_HIDDEN_COUNT:-false}" || return "$EXIT_APPLY_FAILED"
}

gnome_extensions_apply() {
  local dash_uuid="${DASH_TO_DOCK_UUID:-dash-to-dock@micxgx.gmail.com}"
  local blur_uuid="${BLUR_MY_SHELL_UUID:-blur-my-shell@aunetx}"
  local indicator_uuid="${APPINDICATOR_UUID:-appindicatorsupport@rgcjonas.gmail.com}"
  local ding_uuid="${DING_UUID:-ding@rastersoft.com}"
  local show_desktop_uuid="${SHOW_DESKTOP_PLUS_UUID:-show-desktop-plus@attentivecoder}"
  is_true "${ENABLE_GNOME_EXTENSIONS:-false}" || return 0

  if is_true "${ENABLE_DASH_TO_DOCK:-false}" || is_true "${ENABLE_BLUR_MY_SHELL:-false}" || is_true "${ENABLE_APPINDICATOR:-false}"; then
    install_manifest_packages GNOME "$REPO_ROOT/manifests/packages-gnome-extensions.txt" || return "$EXIT_APPLY_FAILED"
  fi

  if is_true "${ENABLE_DESKTOP_ICONS_NG:-false}"; then
    run_mutating GNOME bash "$REPO_ROOT/scripts/gnome/install-ding.sh" \
      "${DING_SOURCE_URL:-}" "$ding_uuid" "${DING_SHELL_VERSION:-50}" || return "$EXIT_APPLY_FAILED"
  fi
  if is_true "${ENABLE_SHOW_DESKTOP_PLUS:-false}"; then
    run_mutating GNOME bash "$REPO_ROOT/scripts/gnome/install-show-desktop-plus.sh" \
      "${SHOW_DESKTOP_PLUS_SOURCE_URL:-}" "$show_desktop_uuid" "${SHOW_DESKTOP_PLUS_SHELL_VERSION:-50}" || return "$EXIT_APPLY_FAILED"
  fi

  if is_true "${ENABLE_DESKTOP_ICONS_NG:-false}"; then
    gnome_ding_settings_apply || return "$EXIT_APPLY_FAILED"
  fi
  if is_true "${ENABLE_SHOW_DESKTOP_PLUS:-false}"; then
    gnome_show_desktop_plus_settings_apply || return "$EXIT_APPLY_FAILED"
  fi

  if ! is_true "${DRY_RUN:-true}"; then
    if is_true "${ENABLE_DASH_TO_DOCK:-false}"; then
      gnome_extension_enable_checked 'Dash to Dock' "$dash_uuid" || return "$EXIT_APPLY_FAILED"
    fi
    if is_true "${ENABLE_BLUR_MY_SHELL:-false}"; then
      gnome_extension_enable_checked 'Blur My Shell' "$blur_uuid" || return "$EXIT_APPLY_FAILED"
    fi
    if is_true "${ENABLE_APPINDICATOR:-false}"; then
      gnome_extension_enable_checked AppIndicator "$indicator_uuid" || return "$EXIT_APPLY_FAILED"
    fi
    if is_true "${ENABLE_DESKTOP_ICONS_NG:-false}"; then
      gnome_extension_enable_checked 'Desktop Icons NG' "$ding_uuid" || return "$EXIT_APPLY_FAILED"
    fi
    if is_true "${ENABLE_SHOW_DESKTOP_PLUS:-false}"; then
      gnome_extension_enable_checked 'Show Desktop Plus' "$show_desktop_uuid" || return "$EXIT_APPLY_FAILED"
    fi
  fi

  if is_true "${INSTALL_EXTENSION_MANAGER:-false}"; then
    is_true "${ENABLE_FLATHUB:-true}" || { log_error GNOME 'Extension Manager requires Flathub in this profile'; return "$EXIT_APPLY_FAILED"; }
    run_mutating GNOME flatpak install -y flathub "${EXTENSION_MANAGER_FLATPAK_ID:-com.mattjakeman.ExtensionManager}" || return "$EXIT_APPLY_FAILED"
  fi
}

gnome_extensions_postcheck() {
  local dash_uuid="${DASH_TO_DOCK_UUID:-dash-to-dock@micxgx.gmail.com}"
  local blur_uuid="${BLUR_MY_SHELL_UUID:-blur-my-shell@aunetx}"
  local indicator_uuid="${APPINDICATOR_UUID:-appindicatorsupport@rgcjonas.gmail.com}"
  local ding_uuid="${DING_UUID:-ding@rastersoft.com}"
  local ding_schema="${DING_SCHEMA:-org.gnome.shell.extensions.ding}"
  local ding_schema_dir
  local show_desktop_uuid="${SHOW_DESKTOP_PLUS_UUID:-show-desktop-plus@attentivecoder}"
  local show_schema="${SHOW_DESKTOP_PLUS_SCHEMA:-org.gnome.shell.extensions.show-desktop-plus}"
  local show_schema_dir
  ding_schema_dir="$(gnome_ding_schema_dir)"
  show_schema_dir="$(gnome_show_desktop_plus_schema_dir)"
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_GNOME_EXTENSIONS:-false}" || return 0

  if is_true "${ENABLE_DASH_TO_DOCK:-false}"; then
    rpm -q "${DASH_TO_DOCK_PACKAGE:-gnome-shell-extension-dash-to-dock}" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
    gnome-extensions info "$dash_uuid" 2>/dev/null | grep -Fq 'State: ENABLED' || return "$EXIT_POSTCHECK_FAILED"
  fi

  if is_true "${ENABLE_BLUR_MY_SHELL:-false}"; then
    rpm -q "${BLUR_MY_SHELL_PACKAGE:-gnome-shell-extension-blur-my-shell}" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
    gnome-extensions info "$blur_uuid" 2>/dev/null | grep -Fq 'State: ENABLED' || return "$EXIT_POSTCHECK_FAILED"
  fi

  if is_true "${ENABLE_APPINDICATOR:-false}"; then
    rpm -q "${APPINDICATOR_PACKAGE:-gnome-shell-extension-appindicator}" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
    gnome-extensions info "$indicator_uuid" 2>/dev/null | grep -Fq 'State: ENABLED' || return "$EXIT_POSTCHECK_FAILED"
  fi

  if is_true "${ENABLE_DESKTOP_ICONS_NG:-false}"; then
    local ding_dir="${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$ding_uuid"
    [[ -r "$ding_dir/metadata.json" ]] || return "$EXIT_POSTCHECK_FAILED"
    grep -Fxq "source_url=${DING_SOURCE_URL:-}" "$ding_dir/.fedora-gnome-custom-source" || return "$EXIT_POSTCHECK_FAILED"
    gnome-extensions info "$ding_uuid" 2>/dev/null | grep -Fq 'State: ENABLED' || return "$EXIT_POSTCHECK_FAILED"
    [[ "$(xdg-user-dir DESKTOP)" == "$HOME/${DING_DESKTOP_DIR_NAME:-Bureau}" ]] || return "$EXIT_POSTCHECK_FAILED"
    [[ "$(gsettings --schemadir "$ding_schema_dir" get "$ding_schema" show-trash)" == "true" ]] || return "$EXIT_POSTCHECK_FAILED"
    [[ "$(gsettings --schemadir "$ding_schema_dir" get "$ding_schema" show-home)" == "false" ]] || return "$EXIT_POSTCHECK_FAILED"
    [[ "$(gsettings --schemadir "$ding_schema_dir" get "$ding_schema" show-volumes)" == "false" ]] || return "$EXIT_POSTCHECK_FAILED"
    [[ "$(gsettings --schemadir "$ding_schema_dir" get "$ding_schema" show-network-volumes)" == "false" ]] || return "$EXIT_POSTCHECK_FAILED"
  fi

  if is_true "${ENABLE_SHOW_DESKTOP_PLUS:-false}"; then
    [[ -r "${XDG_DATA_HOME:-$HOME/.local/share}/gnome-shell/extensions/$show_desktop_uuid/metadata.json" ]] || return "$EXIT_POSTCHECK_FAILED"
    gnome-extensions info "$show_desktop_uuid" 2>/dev/null | grep -Fq 'State: ENABLED' || return "$EXIT_POSTCHECK_FAILED"
    [[ "$(gsettings --schemadir "$show_schema_dir" get "$show_schema" button-position)" == "'${SHOW_DESKTOP_PLUS_BUTTON_POSITION:-left-end}'" ]] || return "$EXIT_POSTCHECK_FAILED"
    [[ "$(gsettings --schemadir "$show_schema_dir" get "$show_schema" left-click-action)" == "'${SHOW_DESKTOP_PLUS_LEFT_CLICK_ACTION:-toggle-desktop}'" ]] || return "$EXIT_POSTCHECK_FAILED"
    [[ "$(gsettings --schemadir "$show_schema_dir" get "$show_schema" enable-hotkey)" == "true" ]] || return "$EXIT_POSTCHECK_FAILED"
    [[ "$(gsettings --schemadir "$show_schema_dir" get "$show_schema" show-desktop-hotkey)" == "['${SHOW_DESKTOP_PLUS_HOTKEY:-<Super>d}']" ]] || return "$EXIT_POSTCHECK_FAILED"
    [[ "$(gsettings --schemadir "$show_schema_dir" get "$show_schema" show-hidden-count)" == "false" ]] || return "$EXIT_POSTCHECK_FAILED"
  fi

  if is_true "${INSTALL_EXTENSION_MANAGER:-false}"; then
    flatpak info "${EXTENSION_MANAGER_FLATPAK_ID:-com.mattjakeman.ExtensionManager}" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  fi
}

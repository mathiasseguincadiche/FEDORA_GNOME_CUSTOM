#!/usr/bin/env bash
# Ubuntu-grade finishing layer on top of upstream GNOME 50 (ADR 0013).
# Every setting is declared in config/gnome-polish.conf, applied here and
# re-verified by postcheck and diagnostics/polish-doctor.
set -Eeuo pipefail

POLISH_DOCK_SCHEMA='org.gnome.shell.extensions.dash-to-dock'
POLISH_INTERFACE_SCHEMA='org.gnome.desktop.interface'
POLISH_MUTTER_SCHEMA='org.gnome.mutter'

# Desired state as "schema|key|gvariant" lines. Used by apply AND postcheck, so
# what is written and what is verified can never drift apart.
gnome_polish_desired_settings() {
  if is_true "${POLISH_DOCK_ENABLED:-true}" && is_true "${ENABLE_DASH_TO_DOCK:-true}"; then
    printf '%s|%s|%s\n' \
      "$POLISH_DOCK_SCHEMA" dock-position "'${POLISH_DOCK_POSITION:-LEFT}'" \
      "$POLISH_DOCK_SCHEMA" extend-height "${POLISH_DOCK_EXTEND_HEIGHT:-true}" \
      "$POLISH_DOCK_SCHEMA" dock-fixed "${POLISH_DOCK_FIXED:-true}" \
      "$POLISH_DOCK_SCHEMA" dash-max-icon-size "${POLISH_DOCK_ICON_SIZE:-48}" \
      "$POLISH_DOCK_SCHEMA" click-action "'${POLISH_DOCK_CLICK_ACTION:-focus-minimize-or-previews}'" \
      "$POLISH_DOCK_SCHEMA" running-indicator-style "'${POLISH_DOCK_RUNNING_INDICATOR:-DOTS}'" \
      "$POLISH_DOCK_SCHEMA" show-trash "${POLISH_DOCK_SHOW_TRASH:-false}" \
      "$POLISH_DOCK_SCHEMA" show-mounts "${POLISH_DOCK_SHOW_MOUNTS:-false}" \
      "$POLISH_DOCK_SCHEMA" disable-overview-on-startup "${POLISH_START_ON_DESKTOP:-true}"
  fi
  printf '%s|%s|%s\n' \
    "$POLISH_INTERFACE_SCHEMA" accent-color "'${POLISH_ACCENT_COLOR:-orange}'" \
    "$POLISH_INTERFACE_SCHEMA" clock-show-weekday "${POLISH_CLOCK_SHOW_WEEKDAY:-true}" \
    "$POLISH_MUTTER_SCHEMA" center-new-windows "${POLISH_CENTER_NEW_WINDOWS:-true}"
}

gnome_polish_precheck() {
  local icon_size
  is_true "${GNOME_POLISH_ENABLED:-true}" || return 0
  command_exists gsettings || { log_error GNOME 'gsettings is required for the polish layer'; return "$EXIT_PRECHECK_FAILED"; }
  case "${POLISH_ACCENT_COLOR:-orange}" in
    blue|teal|green|yellow|orange|red|pink|purple|slate) ;;
    *) log_error GNOME "Unsupported accent color: ${POLISH_ACCENT_COLOR:-}"; return "$EXIT_CONFIG_FAILED" ;;
  esac
  icon_size="${POLISH_DOCK_ICON_SIZE:-48}"
  if [[ ! "$icon_size" =~ ^[0-9]+$ ]] || (( 10#$icon_size < 16 || 10#$icon_size > 128 )); then
    log_error GNOME "Dock icon size must be between 16 and 128, got $icon_size"
    return "$EXIT_CONFIG_FAILED"
  fi
  if is_true "${ENABLE_TILING_ASSISTANT:-true}"; then
    [[ "${TILING_ASSISTANT_UUID:-}" == 'tiling-assistant@leleat-on-github' ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${TILING_ASSISTANT_SOURCE_URL:-}" == https://github.com/Leleat/Tiling-Assistant/releases/download/v55/* ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${TILING_ASSISTANT_SHELL_VERSION:-}" == '50' ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${TILING_ASSISTANT_SHA256:-}" =~ ^[0-9a-f]{64}$ ]] || return "$EXIT_PRECHECK_FAILED"
  fi
}

gnome_polish_plan() {
  cat <<EOF
UBUNTU-GRADE POLISH PLAN:
- Dock: ${POLISH_DOCK_POSITION:-LEFT}, full height, always visible, ${POLISH_DOCK_ICON_SIZE:-48}px icons, click = ${POLISH_DOCK_CLICK_ACTION:-focus-minimize-or-previews}
- Session opens on the desktop instead of the Activities overview: ${POLISH_START_ON_DESKTOP:-true}
- Accent color ${POLISH_ACCENT_COLOR:-orange}, weekday in the clock, new windows centered
- Legacy GTK3 apps use adw-gtk3 and follow the light/dark switch automatically
- Tiling Assistant v${TILING_ASSISTANT_VERSION:-55} (Ubuntu Enhanced Tiling), pinned by URL and SHA-256
EOF
}

gnome_polish_apply() {
  local schema key value
  is_true "${GNOME_POLISH_ENABLED:-true}" || return 0

  if is_true "${POLISH_GTK3_ADWAITA_LOOK:-true}"; then
    install_manifest_packages GNOME "$REPO_ROOT/manifests/packages-gnome-polish.txt" || return "$EXIT_APPLY_FAILED"
  fi
  if is_true "${ENABLE_TILING_ASSISTANT:-true}"; then
    run_mutating GNOME bash "$REPO_ROOT/scripts/gnome/install-tiling-assistant.sh" \
      "${TILING_ASSISTANT_SOURCE_URL:-}" "${TILING_ASSISTANT_UUID:-}" "${TILING_ASSISTANT_SHELL_VERSION:-50}" || return "$EXIT_APPLY_FAILED"
  fi

  while IFS='|' read -r schema key value; do
    [[ -n "$schema" ]] || continue
    run_mutating GNOME gsettings set "$schema" "$key" "$value" || return "$EXIT_APPLY_FAILED"
  done < <(gnome_polish_desired_settings)

  is_true "${DRY_RUN:-true}" && return 0

  if is_true "${POLISH_GTK3_ADWAITA_LOOK:-true}"; then
    install -d -m 0755 "$HOME/.local/libexec" "$HOME/.config/systemd/user"
    install -m 0755 "$REPO_ROOT/scripts/gnome/gtk3-theme-follow.sh" "$HOME/.local/libexec/fedora-gnome-gtk3-theme-follow"
    install -m 0644 "$REPO_ROOT/systemd/user/fedora-gnome-gtk3-theme-follow.service" "$HOME/.config/systemd/user/fedora-gnome-gtk3-theme-follow.service"
    "$HOME/.local/libexec/fedora-gnome-gtk3-theme-follow" once || return "$EXIT_APPLY_FAILED"
    systemctl --user daemon-reload
    systemctl --user enable --now fedora-gnome-gtk3-theme-follow.service || return "$EXIT_APPLY_FAILED"
  fi
  if is_true "${ENABLE_TILING_ASSISTANT:-true}"; then
    if gnome-extensions list 2>/dev/null | grep -Fxq "${TILING_ASSISTANT_UUID:-}"; then
      gnome-extensions info "${TILING_ASSISTANT_UUID:-}" 2>/dev/null | grep -Fq 'State: ENABLED' \
        || run_mutating GNOME gnome-extensions enable "${TILING_ASSISTANT_UUID:-}" || return "$EXIT_APPLY_FAILED"
    else
      log_warn GNOME 'Tiling Assistant installed; log out/in once, then rerun APPLY to enable it'
    fi
  fi
}

gnome_polish_postcheck() {
  local schema key value actual failed=0 scheme expected_theme
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${GNOME_POLISH_ENABLED:-true}" || return 0
  while IFS='|' read -r schema key value; do
    [[ -n "$schema" ]] || continue
    actual="$(gsettings get "$schema" "$key" 2>/dev/null || printf 'unavailable')"
    if [[ "$actual" != "$value" ]]; then
      log_error GNOME "polish drift: $schema $key expected=$value actual=$actual"
      failed=1
    fi
  done < <(gnome_polish_desired_settings)
  if is_true "${POLISH_GTK3_ADWAITA_LOOK:-true}"; then
    rpm -q adw-gtk3-theme >/dev/null 2>&1 || { log_error GNOME 'adw-gtk3-theme is not installed'; failed=1; }
    scheme="$(gsettings get "$POLISH_INTERFACE_SCHEMA" color-scheme 2>/dev/null || printf 'default')"
    expected_theme="$(bash "$REPO_ROOT/scripts/gnome/gtk3-theme-follow.sh" theme-for "$scheme")"
    [[ "$(gsettings get "$POLISH_INTERFACE_SCHEMA" gtk-theme 2>/dev/null)" == "'$expected_theme'" ]] || { log_error GNOME "GTK3 theme is not $expected_theme"; failed=1; }
  fi
  if is_true "${ENABLE_TILING_ASSISTANT:-true}"; then
    gnome-extensions info "${TILING_ASSISTANT_UUID:-}" 2>/dev/null | grep -Fq 'State: ENABLED' || { log_error GNOME 'Tiling Assistant is not enabled'; failed=1; }
  fi
  (( failed == 0 )) || return "$EXIT_POSTCHECK_FAILED"
}

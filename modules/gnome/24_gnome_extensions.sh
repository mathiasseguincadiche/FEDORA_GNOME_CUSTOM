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

  if is_true "${ENABLE_JUST_PERFECTION:-false}"; then
    log_error GNOME 'Just Perfection is explicitly excluded by the workstation desktop policy'
    return "$EXIT_PRECHECK_FAILED"
  fi
}

gnome_extensions_plan() {
  cat <<'EOF'
GNOME EXTENSIONS PLAN:
- Fedora 44 / GNOME 50 Tokyo remains the desktop reference
- Dash to Dock is enabled by default from the official Fedora RPM
- Blur My Shell is enabled by default from the official Fedora RPM after the hardware/graphics baseline gate
- Extension Manager is installed from Flathub as the administration UI
- preserve Dash to Dock and Blur My Shell upstream/Fedora defaults; no aggressive cosmetic preset is forced
- Just Perfection is explicitly excluded
- no other third-party GNOME Shell extension is enabled automatically
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

gnome_extensions_apply() {
  local dash_uuid="${DASH_TO_DOCK_UUID:-dash-to-dock@micxgx.gmail.com}"
  local blur_uuid="${BLUR_MY_SHELL_UUID:-blur-my-shell@aunetx}"
  is_true "${ENABLE_GNOME_EXTENSIONS:-false}" || return 0

  if is_true "${ENABLE_DASH_TO_DOCK:-false}" || is_true "${ENABLE_BLUR_MY_SHELL:-false}"; then
    install_manifest_packages GNOME "$REPO_ROOT/manifests/packages-gnome-extensions.txt" || return "$EXIT_APPLY_FAILED"
  fi

  if ! is_true "${DRY_RUN:-true}"; then
    if is_true "${ENABLE_DASH_TO_DOCK:-false}"; then
      gnome_extension_enable_checked 'Dash to Dock' "$dash_uuid" || return "$EXIT_APPLY_FAILED"
    fi
    if is_true "${ENABLE_BLUR_MY_SHELL:-false}"; then
      gnome_extension_enable_checked 'Blur My Shell' "$blur_uuid" || return "$EXIT_APPLY_FAILED"
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

  if is_true "${INSTALL_EXTENSION_MANAGER:-false}"; then
    flatpak info "${EXTENSION_MANAGER_FLATPAK_ID:-com.mattjakeman.ExtensionManager}" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  fi
}

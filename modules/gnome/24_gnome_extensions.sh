#!/usr/bin/env bash
set -Eeuo pipefail

gnome_extensions_precheck() {
  is_true "${ENABLE_GNOME_EXTENSIONS:-false}" || return 0
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"
  if is_true "${ENABLE_DASH_TO_DOCK:-false}"; then
    [[ "${DASH_TO_DOCK_PACKAGE:-}" == "gnome-shell-extension-dash-to-dock" ]] || return "$EXIT_PRECHECK_FAILED"
    [[ "${DASH_TO_DOCK_UUID:-}" == "dash-to-dock@micxgx.gmail.com" ]] || return "$EXIT_PRECHECK_FAILED"
  fi
}

gnome_extensions_plan() {
  cat <<'EOF'
GNOME EXTENSIONS PLAN:
- Fedora 44 / GNOME 50 remains the desktop reference
- Dash to Dock is the single project-selected GNOME Shell extension enabled by default
- install Dash to Dock from the official Fedora RPM, not from an unmanaged archive
- preserve the extension's upstream/Fedora settings; do not force cosmetic preferences
- Extension Manager remains optional and is not required for Dash to Dock
- no other third-party extension is enabled automatically
EOF
}

gnome_extensions_apply() {
  local uuid="${DASH_TO_DOCK_UUID:-dash-to-dock@micxgx.gmail.com}"
  is_true "${ENABLE_GNOME_EXTENSIONS:-false}" || return 0

  if is_true "${ENABLE_DASH_TO_DOCK:-false}"; then
    install_manifest_packages GNOME "$REPO_ROOT/manifests/packages-gnome-extensions.txt" || return "$EXIT_APPLY_FAILED"

    if ! is_true "${DRY_RUN:-true}"; then
      command_exists gnome-extensions || { log_error GNOME 'gnome-extensions command unavailable'; return "$EXIT_APPLY_FAILED"; }
      if ! gnome-extensions list 2>/dev/null | grep -Fxq "$uuid"; then
        log_error GNOME 'Dash to Dock RPM is installed but the running GNOME session does not see it; log out/in and rerun APPLY'
        return "$EXIT_APPLY_FAILED"
      fi
      if ! gnome-extensions info "$uuid" 2>/dev/null | grep -Fq 'State: ENABLED'; then
        run_mutating GNOME gnome-extensions enable "$uuid" || return "$EXIT_APPLY_FAILED"
      fi
    fi
  fi

  if is_true "${INSTALL_EXTENSION_MANAGER:-false}" && is_true "${ENABLE_FLATHUB:-true}"; then
    run_mutating GNOME flatpak install -y flathub com.mattjakeman.ExtensionManager || return "$EXIT_APPLY_FAILED"
  fi
}

gnome_extensions_postcheck() {
  local uuid="${DASH_TO_DOCK_UUID:-dash-to-dock@micxgx.gmail.com}"
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_GNOME_EXTENSIONS:-false}" || return 0

  if is_true "${ENABLE_DASH_TO_DOCK:-false}"; then
    rpm -q "${DASH_TO_DOCK_PACKAGE:-gnome-shell-extension-dash-to-dock}" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
    gnome-extensions list 2>/dev/null | grep -Fxq "$uuid" || return "$EXIT_POSTCHECK_FAILED"
    gnome-extensions info "$uuid" 2>/dev/null | grep -Fq 'State: ENABLED' || return "$EXIT_POSTCHECK_FAILED"
  fi
}

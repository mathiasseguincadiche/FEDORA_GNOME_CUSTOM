#!/usr/bin/env bash
set -Eeuo pipefail

desktop_integration_precheck() {
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"
}

desktop_integration_plan() {
  cat <<'EOF'
Complete Fedora GNOME daily-workstation integration:
- Secret Service / GNOME Keyring
- driverless CUPS/IPP + Avahi + AirScan capability
- OpenVPN/OpenConnect GNOME integration
- Fedora TuneD power-profile bridge
- French dictionaries and document-compatible fonts
- Remmina RDP/VNC/SSH client stack
- mobile/iPhone filesystem support
- Intel Arc Level Zero/OpenCL compute
- functional Wayland/Flatpak portal surfaces
- legacy input-method workaround remains opt-in and is never coupled to Nautilus
EOF
}

desktop_integration_apply() {
  install_manifest_packages DESKTOP "$REPO_ROOT/manifests/packages-desktop-integration.txt" || return "$EXIT_APPLY_FAILED"

  if is_true "${REMOVE_IBUS_TYPING_BOOSTER:-false}" && rpm -q ibus-typing-booster >/dev/null 2>&1; then
    run_mutating DESKTOP sudo dnf -y remove ibus-typing-booster || return "$EXIT_APPLY_FAILED"
  fi

  run_mutating DESKTOP sudo systemctl enable --now cups.socket || return "$EXIT_APPLY_FAILED"
  run_mutating DESKTOP sudo systemctl enable --now avahi-daemon.service || return "$EXIT_APPLY_FAILED"
  run_mutating DESKTOP sudo systemctl enable --now tuned.service || return "$EXIT_APPLY_FAILED"
  run_mutating DESKTOP sudo systemctl start tuned-ppd.service || return "$EXIT_APPLY_FAILED"

  if is_true "${DESKTOP_REQUIRE_FRENCH_LANGUAGE:-true}"; then
    run_mutating DESKTOP sudo localectl set-locale "LANG=${DESKTOP_LOCALE:-fr_FR.UTF-8}" || return "$EXIT_APPLY_FAILED"
  fi
}

desktop_integration_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  "$REPO_ROOT/diagnostics/desktop-integration-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
  "$REPO_ROOT/diagnostics/portal-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
  "$REPO_ROOT/diagnostics/arc-compute-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
}

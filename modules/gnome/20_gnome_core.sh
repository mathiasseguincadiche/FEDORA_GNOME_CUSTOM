#!/usr/bin/env bash
set -Eeuo pipefail
gnome_core_precheck() { command_exists dnf; }
gnome_core_plan() { echo 'Install/validate Fedora GNOME core, portals and Flatpak; preserve font/rendering defaults and let GNOME Shell close its own children before final service cleanup. Nautilus integration is converged by the dedicated gnome.nautilus module.'; }
gnome_core_apply() {
  install_manifest_packages GNOME "$REPO_ROOT/manifests/packages-gnome.txt" || return "$EXIT_APPLY_FAILED"
  if [[ "${HOST_RELEASE:-45}" == 45 ]]; then
    run_mutating GNOME bash "$REPO_ROOT/scripts/gnome/configure-shell-lifecycle.sh" apply || return "$EXIT_APPLY_FAILED"
  fi
}
gnome_core_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  rpm -q gnome-shell mutter gnome-control-center xdg-desktop-portal-gnome >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  if [[ "${HOST_RELEASE:-45}" == 45 ]]; then
    bash "$REPO_ROOT/scripts/gnome/configure-shell-lifecycle.sh" verify || return "$EXIT_POSTCHECK_FAILED"
  fi
}

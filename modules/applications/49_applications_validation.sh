#!/usr/bin/env bash
set -Eeuo pipefail

applications_validation_precheck() {
  [[ -r "$REPO_ROOT/manifests/packages-applications-gtk4.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/packages-applications-professional-fedora.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/packages-applications-professional-vendor.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/flatpaks-applications-professional.txt" ]] || return "$EXIT_PRECHECK_FAILED"
}

applications_validation_plan() {
  echo 'Validate the GNOME GTK4/libadwaita desktop set, professional application exceptions, Flatpak apps and the managed Ptyxis terminal.'
}

applications_validation_apply() { log_info APPLICATIONS 'application validation is read-only'; }

applications_validation_postcheck() {
  local pkg app manifest
  is_true "${DRY_RUN:-true}" && return 0

  for manifest in \
    "$REPO_ROOT/manifests/packages-applications-gtk4.txt" \
    "$REPO_ROOT/manifests/packages-applications-professional-fedora.txt" \
    "$REPO_ROOT/manifests/packages-applications-professional-vendor.txt"; do
    while IFS= read -r pkg; do
      [[ -z "$pkg" || "$pkg" == \#* ]] && continue
      rpm -q "$pkg" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
    done < "$manifest"
  done

  rpm -q "${TERMINAL_PACKAGE:-ptyxis}" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  rpm -q "${TEXT_EDITOR_PACKAGE:-gnome-text-editor}" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"

  if is_true "${ENABLE_PROFESSIONAL_FLATPAKS:-true}"; then
    while IFS= read -r app; do
      [[ -z "$app" || "$app" == \#* ]] && continue
      flatpak info "$app" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
    done < "$REPO_ROOT/manifests/flatpaks-applications-professional.txt"
  fi
}

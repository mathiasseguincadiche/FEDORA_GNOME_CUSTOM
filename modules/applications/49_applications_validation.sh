#!/usr/bin/env bash
set -Eeuo pipefail

applications_validation_precheck() {
  [[ -r "$REPO_ROOT/manifests/packages-applications-gtk4.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/packages-applications-professional-fedora.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/packages-applications-professional-vendor.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/flatpaks-applications-professional.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/application-runtime-contract.tsv" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/packages-appimage.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/flatpaks-appimage.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -x "$REPO_ROOT/scripts/gnome/configure-default-apps.sh" ]] || return "$EXIT_PRECHECK_FAILED"
}

applications_validation_plan() {
  echo 'Validate GTK4/libadwaita apps, professional RPM/Flatpak provenance and actual runtime startup, AppImage compatibility, Nautilus/Ptyxis integration, and deterministic GNOME default application associations.'
}

applications_validation_apply() {
  is_true "${GNOME_DEFAULT_APPS_ENABLED:-true}" || return 0
  is_true "${DRY_RUN:-true}" && { log_info APPLICATIONS 'DRY-RUN: configure GNOME default application associations'; return 0; }
  "$REPO_ROOT/scripts/gnome/configure-default-apps.sh" full || return "$EXIT_APPLY_FAILED"
}

applications_validation_postcheck() {
  local pkg app manifest
  is_true "${DRY_RUN:-true}" && return 0

  for manifest in \
    "$REPO_ROOT/manifests/packages-applications-gtk4.txt" \
    "$REPO_ROOT/manifests/packages-applications-professional-fedora.txt" \
    "$REPO_ROOT/manifests/packages-applications-professional-vendor.txt" \
    "$REPO_ROOT/manifests/packages-appimage.txt"; do
    while IFS= read -r pkg; do
      [[ -z "$pkg" || "$pkg" == \#* ]] && continue
      rpm -q "$pkg" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
    done < "$manifest"
  done

  rpm -q "${TERMINAL_PACKAGE:-ptyxis}" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  rpm -q "${TEXT_EDITOR_PACKAGE:-gnome-text-editor}" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  "$REPO_ROOT/diagnostics/ptyxis-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
  "$REPO_ROOT/diagnostics/ptyxis-integration-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
  "$REPO_ROOT/diagnostics/nautilus-ptyxis-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
  "$REPO_ROOT/diagnostics/default-apps-doctor" --quiet --full || return "$EXIT_POSTCHECK_FAILED"
  "$REPO_ROOT/diagnostics/appimage-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
  "$REPO_ROOT/diagnostics/application-runtime-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"

  if is_true "${ENABLE_PROFESSIONAL_FLATPAKS:-true}"; then
    for manifest in \
      "$REPO_ROOT/manifests/flatpaks-applications-professional.txt" \
      "$REPO_ROOT/manifests/flatpaks-appimage.txt"; do
      while IFS= read -r app; do
        [[ -z "$app" || "$app" == \#* ]] && continue
        flatpak info "$app" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
      done < "$manifest"
    done
  fi
}

#!/usr/bin/env bash
set -Eeuo pipefail

appimage_compat_precheck() {
  [[ -r "$REPO_ROOT/manifests/packages-appimage.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/flatpaks-appimage.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -x "$REPO_ROOT/scripts/appimage/appimage-run" ]] || return "$EXIT_PRECHECK_FAILED"
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"
  [[ "$(uname -m)" == x86_64 ]] || { log_error APPLICATIONS 'Golden AppImage multilib profile requires x86_64'; return "$EXIT_PRECHECK_FAILED"; }
}

appimage_compat_plan() {
  echo 'Install Fedora FUSE 2 + FUSE 3, x86_64/i686 compatibility libraries, Type 1 ISO9660 and Type 2 SquashFS extraction helpers, the managed appimage-run compatibility command, and Gear Lever desktop integration from Flathub.'
}

appimage_compat_apply() {
  local app
  install_manifest_packages APPLICATIONS "$REPO_ROOT/manifests/packages-appimage.txt" || return "$EXIT_APPLY_FAILED"
  run_mutating APPLICATIONS sudo install -Dm0755 "$REPO_ROOT/scripts/appimage/appimage-run" /usr/local/bin/appimage-run || return "$EXIT_APPLY_FAILED"

  if is_true "${ENABLE_FLATHUB:-true}" && is_true "${ENABLE_PROFESSIONAL_FLATPAKS:-true}"; then
    while IFS= read -r app; do
      [[ -z "$app" || "$app" == \#* ]] && continue
      run_mutating APPLICATIONS flatpak install -y flathub "$app" || return "$EXIT_APPLY_FAILED"
    done < "$REPO_ROOT/manifests/flatpaks-appimage.txt"
  fi
}

appimage_compat_postcheck() {
  local pkg app
  is_true "${DRY_RUN:-true}" && return 0

  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    rpm -q "$pkg" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  done < "$REPO_ROOT/manifests/packages-appimage.txt"

  command_exists fusermount || return "$EXIT_POSTCHECK_FAILED"
  command_exists fusermount3 || return "$EXIT_POSTCHECK_FAILED"
  command_exists bsdtar || return "$EXIT_POSTCHECK_FAILED"
  command_exists unsquashfs || return "$EXIT_POSTCHECK_FAILED"
  command_exists appimage-run || return "$EXIT_POSTCHECK_FAILED"

  if is_true "${ENABLE_FLATHUB:-true}" && is_true "${ENABLE_PROFESSIONAL_FLATPAKS:-true}"; then
    while IFS= read -r app; do
      [[ -z "$app" || "$app" == \#* ]] && continue
      flatpak info "$app" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
    done < "$REPO_ROOT/manifests/flatpaks-appimage.txt"
  fi

  "$REPO_ROOT/diagnostics/appimage-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
}

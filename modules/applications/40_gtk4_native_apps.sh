#!/usr/bin/env bash
set -Eeuo pipefail

applications_gtk4_precheck() {
  command_exists dnf
  [[ -r "$REPO_ROOT/manifests/packages-applications-gtk4.txt" ]]
}

applications_gtk4_plan() {
  echo 'Install the curated GNOME GTK4/libadwaita desktop application set. Ptyxis is the managed terminal. Applications not verified against this policy are not auto-managed.'
}

applications_gtk4_apply() {
  install_manifest_packages APPLICATIONS "$REPO_ROOT/manifests/packages-applications-gtk4.txt"
}

applications_gtk4_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  local pkg
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    rpm -q "$pkg" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  done < "$REPO_ROOT/manifests/packages-applications-gtk4.txt"
  command_exists "${TERMINAL_PACKAGE:-ptyxis}" || return "$EXIT_POSTCHECK_FAILED"
}

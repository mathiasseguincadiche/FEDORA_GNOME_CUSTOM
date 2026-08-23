#!/usr/bin/env bash
set -Eeuo pipefail

applications_validation_precheck() { [[ -r "$REPO_ROOT/manifests/packages-applications-gtk4.txt" ]]; }
applications_validation_plan() { echo 'Validate the complete GTK4/libadwaita desktop application manifest and the managed Ptyxis terminal.'; }
applications_validation_apply() { log_info APPLICATIONS 'application validation is read-only'; }
applications_validation_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  local pkg
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    rpm -q "$pkg" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  done < "$REPO_ROOT/manifests/packages-applications-gtk4.txt"
  rpm -q "${TERMINAL_PACKAGE:-ptyxis}" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}

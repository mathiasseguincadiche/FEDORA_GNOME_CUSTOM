#!/usr/bin/env bash
set -Eeuo pipefail
system_validation_precheck() { :; }
system_validation_plan() { echo 'Validate Fedora release, DNF/RPM health, SELinux and firewalld after system convergence.'; }
system_validation_apply() { :; }
system_validation_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  grep -Eq '^VERSION_ID="?44"?$' /etc/os-release || return "$EXIT_POSTCHECK_FAILED"
  sudo dnf -q check || return "$EXIT_POSTCHECK_FAILED"
  if is_true "${REQUIRE_SELINUX_ENFORCING:-true}"; then [[ "$(getenforce)" == Enforcing ]] || return "$EXIT_POSTCHECK_FAILED"; fi
}

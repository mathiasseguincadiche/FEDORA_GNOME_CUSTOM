#!/usr/bin/env bash
set -Eeuo pipefail
system_security_precheck() { command_exists dnf; }
system_security_plan() { echo 'Preserve SELinux Enforcing; install/enable firewalld; never disable Fedora security controls for convenience.'; }
system_security_apply() {
  run_mutating SYSTEM sudo dnf -y install policycoreutils firewalld
  run_mutating SYSTEM sudo systemctl enable --now firewalld.service
}
system_security_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  if is_true "${REQUIRE_SELINUX_ENFORCING:-true}"; then [[ "$(getenforce)" == Enforcing ]] || return "$EXIT_POSTCHECK_FAILED"; fi
  if is_true "${REQUIRE_FIREWALLD:-true}"; then systemctl is-active --quiet firewalld || return "$EXIT_POSTCHECK_FAILED"; fi
}

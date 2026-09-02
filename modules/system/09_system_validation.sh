#!/usr/bin/env bash
set -Eeuo pipefail
system_validation_precheck() { :; }
system_validation_plan() { echo 'Validate Fedora release, DNF/RPM health, SELinux, firewalld and the host Python toolchain after system convergence.'; }
system_validation_apply() { :; }
system_validation_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  grep -Eq '^VERSION_ID="?44"?$' /etc/os-release || return "$EXIT_POSTCHECK_FAILED"
  sudo dnf -q check || return "$EXIT_POSTCHECK_FAILED"
  if is_true "${REQUIRE_SELINUX_ENFORCING:-true}"; then [[ "$(getenforce)" == Enforcing ]] || return "$EXIT_POSTCHECK_FAILED"; fi

  rpm -q python3 python3-pip python3-devel pipx >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  command_exists python3 && command_exists pip3 && command_exists pipx || return "$EXIT_POSTCHECK_FAILED"
  python3 -m pip --version >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"

  local venv_root
  venv_root="$(mktemp -d)"
  if ! python3 -m venv "$venv_root/venv" >/dev/null 2>&1; then
    rm -rf "$venv_root"
    return "$EXIT_POSTCHECK_FAILED"
  fi
  "$venv_root/venv/bin/python" -c 'import sys; assert sys.version_info.major == 3' || {
    rm -rf "$venv_root"
    return "$EXIT_POSTCHECK_FAILED"
  }
  rm -rf "$venv_root"
}

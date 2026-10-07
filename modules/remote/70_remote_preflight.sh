#!/usr/bin/env bash
set -Eeuo pipefail

source "$REPO_ROOT/lib/remote_access.sh"

remote_preflight_precheck() {
  remote_enabled || return 0
  local tool
  for tool in dnf nmcli systemctl firewall-cmd python3; do
    command_exists "$tool" || { log_error REMOTE "$tool is required by the remote-access profile"; return "$EXIT_PRECHECK_FAILED"; }
  done
  remote_valid_port_list "${REMOTE_SUNSHINE_TCP_PORTS:-}" || { log_error REMOTE 'REMOTE_SUNSHINE_TCP_PORTS must list valid port numbers'; return "$EXIT_PRECHECK_FAILED"; }
  remote_valid_port_list "${REMOTE_SUNSHINE_UDP_PORTS:-}" || { log_error REMOTE 'REMOTE_SUNSHINE_UDP_PORTS must list valid port numbers'; return "$EXIT_PRECHECK_FAILED"; }
  [[ "${REMOTE_SUNSHINE_TCP_PORTS:-}" != *47990* && "${REMOTE_SUNSHINE_UDP_PORTS:-}" != *47990* ]] || { log_error REMOTE 'the Sunshine web UI port 47990 must never be opened'; return "$EXIT_PRECHECK_FAILED"; }
  is_true "${DRY_RUN:-true}" && return 0
  [[ "$(getenforce 2>/dev/null || echo unknown)" == Enforcing ]] || { log_error REMOTE 'SELinux must stay Enforcing'; return "$EXIT_PRECHECK_FAILED"; }
  systemctl is-active --quiet firewalld || { log_error REMOTE 'firewalld must be active'; return "$EXIT_PRECHECK_FAILED"; }
  # Fail closed before the SSH hardening: password login is switched off, a missing key would lock the remote door.
  remote_authorized_keys_present || { log_error REMOTE "no public key in $HOME/.ssh/authorized_keys: add the tablet key before enabling the profile"; return "$EXIT_PRECHECK_FAILED"; }
  if remote_wol_enabled; then
    remote_wired_interface >/dev/null || { log_error REMOTE "no wired interface bound to ${HARDWARE_LAN_DRIVER:-r8169}"; return "$EXIT_PRECHECK_FAILED"; }
  fi
}

remote_preflight_plan() {
  if remote_enabled; then
    echo 'Check tools, SELinux/firewalld, valid Sunshine ports, a public key for key-only SSH and the wired interface for Wake-on-LAN. No mutation.'
  else
    echo 'Remote-access profile disabled (REMOTE_ENABLE=false): nothing to check.'
  fi
}

remote_preflight_apply() { return 0; }
remote_preflight_postcheck() { return 0; }

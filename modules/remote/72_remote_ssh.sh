#!/usr/bin/env bash
set -Eeuo pipefail

source "$REPO_ROOT/lib/remote_access.sh"

remote_ssh_precheck() {
  remote_enabled || return 0
  [[ -r "$REPO_ROOT/remote/ssh/00-fgc-remote.conf.in" ]] || { log_error REMOTE 'missing SSH hardening template'; return "$EXIT_PRECHECK_FAILED"; }
}

remote_ssh_plan() {
  if remote_enabled; then
    echo 'Harden OpenSSH (public keys only, no root, single allowed user) with a drop-in validated by sshd -t, enable sshd, and keep the ssh service out of the default LAN firewalld zone unless REMOTE_SSH_LAN=true.'
  else
    echo 'Remote-access profile disabled: OpenSSH untouched.'
  fi
}

remote_ssh_apply() {
  remote_enabled || return 0
  local user dropin tmp zone
  user="$(remote_user)"
  dropin="$(remote_sshd_dropin)"
  tmp="$(mktemp)" || return "$EXIT_APPLY_FAILED"
  remote_render_template "$REPO_ROOT/remote/ssh/00-fgc-remote.conf.in" "$user" > "$tmp"
  run_mutating REMOTE sudo install -Dm0644 "$tmp" "$dropin" || { rm -f "$tmp"; return "$EXIT_APPLY_FAILED"; }
  rm -f "$tmp"
  if ! is_true "${DRY_RUN:-true}"; then
    # An invalid sshd configuration would lock the remote door: roll the drop-in back before reloading anything.
    if ! sudo sshd -t; then
      sudo rm -f "$dropin"
      log_error REMOTE 'sshd -t rejected the hardened configuration: drop-in removed'
      return "$EXIT_APPLY_FAILED"
    fi
  fi
  run_mutating REMOTE sudo systemctl enable --now sshd.service || return "$EXIT_APPLY_FAILED"
  run_mutating REMOTE sudo systemctl reload sshd.service || return "$EXIT_APPLY_FAILED"
  if ! is_true "${REMOTE_SSH_LAN:-false}"; then
    zone="$(remote_default_zone || true)"; zone="${zone:-FedoraWorkstation}"
    run_mutating REMOTE sudo firewall-cmd --permanent --zone="$zone" --remove-service=ssh || return "$EXIT_APPLY_FAILED"
    run_mutating REMOTE sudo firewall-cmd --reload || return "$EXIT_APPLY_FAILED"
  fi
}

remote_ssh_postcheck() {
  remote_enabled || return 0
  is_true "${DRY_RUN:-true}" && return 0
  local effective user zone
  user="$(remote_user)"
  systemctl is-active --quiet sshd.service || { log_error REMOTE 'sshd is not active'; return "$EXIT_POSTCHECK_FAILED"; }
  effective="$(sudo sshd -T 2>/dev/null)" || return "$EXIT_POSTCHECK_FAILED"
  grep -Fxq 'passwordauthentication no' <<<"$effective" || { log_error REMOTE 'sshd still accepts passwords'; return "$EXIT_POSTCHECK_FAILED"; }
  grep -Fxq 'permitrootlogin no' <<<"$effective" || { log_error REMOTE 'sshd still allows root login'; return "$EXIT_POSTCHECK_FAILED"; }
  grep -Fxq 'pubkeyauthentication yes' <<<"$effective" || return "$EXIT_POSTCHECK_FAILED"
  grep -Fxq "allowusers $user" <<<"$effective" || { log_error REMOTE "sshd must allow only $user"; return "$EXIT_POSTCHECK_FAILED"; }
  if ! is_true "${REMOTE_SSH_LAN:-false}"; then
    zone="$(remote_default_zone || true)"; zone="${zone:-FedoraWorkstation}"
    if remote_zone_has_service "$zone" ssh; then log_error REMOTE "ssh is still open in the LAN zone $zone"; return "$EXIT_POSTCHECK_FAILED"; fi
  fi
}

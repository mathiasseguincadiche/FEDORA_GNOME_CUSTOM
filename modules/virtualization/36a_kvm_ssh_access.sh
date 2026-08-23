#!/usr/bin/env bash
set -Eeuo pipefail

kvm_ssh_precheck() {
  is_true "${ENABLE_KVM:-true}" || return 0
  return 0
}

kvm_ssh_plan() {
  cat <<'EOF'
HOST-TO-GUEST SSH ACCESS:
- install OpenSSH client tooling on the Fedora HOST
- use operator-owned SSH keys; do not generate or overwrite identity files automatically
- do not weaken host-key checking or guest sshd policy
- Ubuntu Server/Fedora lab profiles are intended to be administered over devops-nat
- runtime connectivity certification is explicit and requires real guest addresses
EOF
}

kvm_ssh_apply() { :; }

kvm_ssh_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KVM:-true}" || return 0
  command_exists ssh || return "$EXIT_POSTCHECK_FAILED"
  command_exists ssh-keygen || return "$EXIT_POSTCHECK_FAILED"
  rpm -q openssh-clients >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}

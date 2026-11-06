#!/usr/bin/env bash
set -Eeuo pipefail

# Accès SSH hôte vers invité : outillage client sur l'hôte, clés appartenant à l'opérateur, jamais générées ni écrasées ; aucun affaiblissement des politiques ; rocky-devops s'administre par SSH sur devops-nat.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).

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
- rocky-devops is administered primarily through SSH on devops-nat
- SFTP/GVfs reuses the same SSH service for graphical Nautilus file access
- runtime connectivity certification is explicit and requires the real guest address
EOF
}

kvm_ssh_apply() { :; }

kvm_ssh_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KVM:-true}" || return 0
  command_exists ssh || return "$EXIT_POSTCHECK_FAILED"
  command_exists sftp || return "$EXIT_POSTCHECK_FAILED"
  command_exists ssh-keygen || return "$EXIT_POSTCHECK_FAILED"
  rpm -q openssh-clients >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}

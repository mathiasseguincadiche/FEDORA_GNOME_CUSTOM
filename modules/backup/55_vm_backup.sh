#!/usr/bin/env bash
set -Eeuo pipefail

# Disques des VM, NVRAM, TPM et média cloud-init : exportés manuellement par le propriétaire, exclus explicitement de Borg.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).
# Contract: no automated VM disk backup or copy, even with local.conf overrides.
backup_vm_precheck() {
  ! is_true "${BACKUP_VM_DISKS:-false}" || return "${EXIT_CONFIG_FAILED:-60}"
  ! is_true "${BACKUP_VM_CLOUD_INIT_METADATA:-false}" || return "${EXIT_CONFIG_FAILED:-60}"
}
backup_vm_plan() { echo 'VM disks, NVRAM, TPM and cloud-init are exported manually by the owner; Borg explicitly excludes them.'; }
backup_vm_apply() { :; }
backup_vm_postcheck() {
  ! is_true "${BACKUP_VM_DISKS:-false}" && ! is_true "${BACKUP_VM_CLOUD_INIT_METADATA:-false}"
}

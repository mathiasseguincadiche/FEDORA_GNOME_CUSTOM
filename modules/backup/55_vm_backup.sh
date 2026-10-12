#!/usr/bin/env bash
set -Eeuo pipefail
# Contract: no automated VM disk backup or copy, even with local.conf overrides.
backup_vm_precheck() {
  ! is_true "${BACKUP_VM_DISKS:-false}" || return "$EXIT_CONFIG_FAILED"
  ! is_true "${BACKUP_VM_CLOUD_INIT_METADATA:-false}" || return "$EXIT_CONFIG_FAILED"
}
backup_vm_plan() { echo 'VM disks, NVRAM, TPM and cloud-init are exported manually by the owner; Borg explicitly excludes them.'; }
backup_vm_apply() { :; }
backup_vm_postcheck() {
  ! is_true "${BACKUP_VM_DISKS:-false}" && ! is_true "${BACKUP_VM_CLOUD_INIT_METADATA:-false}"
}

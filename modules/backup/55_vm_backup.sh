#!/usr/bin/env bash
set -Eeuo pipefail
backup_vm_precheck() {
  is_true "${BACKUP_VM_DISKS:-true}" || return 0
  is_true "${BACKUP_VM_SHUTDOWN_REQUIRED:-true}" || return "$EXIT_PRECHECK_FAILED"
  ! is_true "${BACKUP_ALLOW_LIVE_QCOW2_COPY:-false}" || return "$EXIT_PRECHECK_FAILED"
}
backup_vm_plan() { echo 'VM disk backup is explicit: reference guests must be shut off; qcow2 files are staged with qemu-img convert before Restic capture. Live file-copy backup is forbidden.'; }
backup_vm_apply() { :; }
backup_vm_postcheck() { return 0; }

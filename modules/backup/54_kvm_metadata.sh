#!/usr/bin/env bash
set -Eeuo pipefail
# The owner performs VM exports manually; Borg never exports libvirt metadata.
backup_kvm_precheck() {
  ! is_true "${BACKUP_LIBVIRT_METADATA:-false}" || return "${EXIT_CONFIG_FAILED:-60}"
}
backup_kvm_plan() { echo 'VM domain XML, libvirt pools/networks and NVRAM are owner-managed manual exports; not archived by Borg.'; }
backup_kvm_apply() { :; }
backup_kvm_postcheck() { ! is_true "${BACKUP_LIBVIRT_METADATA:-false}"; }

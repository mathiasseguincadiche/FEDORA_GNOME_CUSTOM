#!/usr/bin/env bash
set -Eeuo pipefail
backup_kvm_precheck() { is_true "${BACKUP_LIBVIRT_METADATA:-true}" || return 0; command_exists virsh; }
backup_kvm_plan() { echo 'Export qemu:///system domain XML, network XML, pool XML, volume inventory and VM identity metadata; generated ISO media are not treated as irreplaceable data.'; }
backup_kvm_apply() { :; }
backup_kvm_postcheck() { is_true "${DRY_RUN:-true}" && return 0; command_exists virsh; }

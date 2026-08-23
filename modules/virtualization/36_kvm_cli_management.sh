#!/usr/bin/env bash
set -Eeuo pipefail

kvm_cli_precheck() {
  is_true "${ENABLE_KVM:-true}" || return 0
  return 0
}

kvm_cli_plan() {
  cat <<'EOF'
KVM CLI MANAGEMENT:
- virsh for domain/network/pool lifecycle and snapshots
- virt-install for reproducible VM creation
- virt-clone for explicit clone workflows
- qemu-img for qcow2 inspection/resize/convert operations
- guestfish/virt-filesystems for offline guest inspection
- osinfo-query for guest metadata
- GUI remains available through virt-manager/virt-viewer, but CLI is fully supported
EOF
}

kvm_cli_apply() { :; }

kvm_cli_postcheck() {
  local cmd
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KVM:-true}" || return 0
  for cmd in virsh virt-install virt-clone qemu-img guestfish virt-filesystems osinfo-query; do
    command_exists "$cmd" || { log_error KVM "missing CLI tool: $cmd"; return "$EXIT_POSTCHECK_FAILED"; }
  done
  virsh --connect "${LIBVIRT_URI:-qemu:///system}" list --all >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-list --all >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-list --all >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}

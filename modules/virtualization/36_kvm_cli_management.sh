#!/usr/bin/env bash
set -Eeuo pipefail

kvm_cli_precheck() {
  is_true "${ENABLE_KVM:-true}" || return 0
  return 0
}

kvm_cli_plan() {
  cat <<'EOF'
KVM CLI MANAGEMENT:
- virsh for domain/network/pool lifecycle, snapshots and console operations
- virt-install / virt-clone / virt-xml for reproducible creation, cloning and XML mutation
- qemu-img for qcow2 inspection, resize, conversion and backing-chain operations
- guestfish plus guestfs-tools for offline inspection and image manipulation
- virt-customize / virt-sysprep for preparing and templating guests
- virt-resize / virt-sparsify for disk image maintenance
- virt-builder for reproducible guest image construction
- virt-top for live domain resource monitoring
- virt-v2v for VM conversion and migration workflows
- virt-qemu-qmp-proxy for QEMU-specific monitor access
- osinfo-query for guest metadata
- ssh/scp/sftp/rsync for host-to-guest administration and transfers
- GUI remains available through virt-manager/virt-viewer, but the full operational path is CLI-first
EOF
}

kvm_cli_apply() { :; }

kvm_cli_postcheck() {
  local cmd
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KVM:-true}" || return 0

  for cmd in \
    virsh virt-install virt-clone virt-xml qemu-img \
    guestfish virt-filesystems virt-customize virt-sysprep virt-resize virt-sparsify virt-builder \
    virt-top virt-v2v virt-qemu-qmp-proxy osinfo-query \
    ssh scp sftp rsync; do
    command_exists "$cmd" || { log_error KVM "missing CLI tool: $cmd"; return "$EXIT_POSTCHECK_FAILED"; }
  done

  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" list --all >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-list --all >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-list --all >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" domcapabilities >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  virt-builder --list >/dev/null 2>&1 || { log_warn KVM 'virt-builder catalog is not currently reachable'; }
}

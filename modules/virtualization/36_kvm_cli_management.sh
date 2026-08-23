#!/usr/bin/env bash
set -Eeuo pipefail

kvm_cli_precheck() {
  is_true "${ENABLE_KVM:-true}" || return 0
  return 0
}

kvm_cli_plan() {
  cat <<'EOF'
KVM CLI MANAGEMENT:
- virsh plus virt-admin for domain/network/pool/daemon lifecycle and snapshots
- virt-host-validate for host capability checks and virt-xml-validate for libvirt XML validation
- virt-install / virt-clone / virt-xml for reproducible creation, cloning and XML mutation
- qemu-img / qemu-io / qemu-nbd / qemu-storage-daemon for image and block-storage operations
- guestfish plus guestfs-tools for offline inspection and image manipulation
- virt-customize / virt-sysprep for preparing and templating guests
- virt-resize / virt-sparsify for disk image maintenance
- virt-builder for reproducible guest image construction
- cloud-localds for explicit NoCloud/cloud-init seed disks
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
    virsh virt-admin virt-host-validate virt-xml-validate \
    virt-install virt-clone virt-xml \
    qemu-img qemu-io qemu-nbd qemu-storage-daemon \
    guestfish virt-filesystems virt-customize virt-sysprep virt-resize virt-sparsify virt-builder \
    cloud-localds virt-top virt-v2v virt-qemu-qmp-proxy osinfo-query \
    ssh scp sftp rsync; do
    command_exists "$cmd" || { log_error KVM "missing CLI tool: $cmd"; return "$EXIT_POSTCHECK_FAILED"; }
  done

  virt-host-validate qemu >/dev/null 2>&1 || { log_warn KVM 'virt-host-validate reports one or more host recommendations'; }
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" list --all >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-list --all >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-list --all >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" domcapabilities >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  virt-builder --list >/dev/null 2>&1 || { log_warn KVM 'virt-builder catalog is not currently reachable'; }
}

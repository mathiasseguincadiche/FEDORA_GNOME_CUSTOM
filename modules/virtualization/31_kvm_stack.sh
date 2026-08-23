#!/usr/bin/env bash
set -Eeuo pipefail
kvm_stack_precheck() { command_exists dnf; }
kvm_stack_plan() { echo 'Install Fedora QEMU/KVM/libvirt, virt-install/virt-manager, OVMF and swtpm; use system libvirt with socket activation.'; }
kvm_stack_apply() {
  is_true "${ENABLE_KVM:-true}" || return 0
  install_manifest_packages KVM "$REPO_ROOT/manifests/packages-virtualization.txt"
  if systemctl list-unit-files virtqemud.socket >/dev/null 2>&1; then
    run_mutating KVM sudo systemctl enable --now virtqemud.socket virtnetworkd.socket
  else
    run_mutating KVM sudo systemctl enable --now libvirtd.service
  fi
  run_mutating KVM sudo usermod -aG libvirt "$USER"
}
kvm_stack_postcheck() { is_true "${DRY_RUN:-true}" && return 0; is_true "${ENABLE_KVM:-true}" || return 0; virsh -c qemu:///system list >/dev/null; }

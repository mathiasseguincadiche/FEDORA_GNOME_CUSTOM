#!/usr/bin/env bash
set -Eeuo pipefail

kvm_validation_precheck() { :; }

kvm_validation_plan() {
  cat <<'EOF'
FINAL KVM VALIDATION:
- AMD KVM acceleration and Arc B580 HOST ownership
- qemu:///system and Fedora libvirt activation
- OVMF/UEFI, swtpm TPM 2.0 and VirtioFS
- dedicated EXT4 storage pool + SELinux labels + autostart
- devops-nat + DNS + firewalld libvirt zone + project LAN isolation guard
- libosinfo catalog, CLI, virt-manager and virt-viewer
- Ubuntu Server, Fedora and Windows 11 profile contract
- no VFIO/GPU passthrough and no automatic VM creation
EOF
}

kvm_validation_apply() { :; }

kvm_validation_postcheck() {
  local pool="${KVM_POOL_NAME:-devops-data}" network="${KVM_NETWORK_NAME:-devops-nat}" mount="${KVM_DATA_MOUNT:-/data}"
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KVM:-true}" || return 0

  [[ -c /dev/kvm && -d /sys/module/kvm_amd ]] || return "$EXIT_POSTCHECK_FAILED"
  is_true "${ALLOW_GPU_PASSTHROUGH:-false}" && return "$EXIT_POSTCHECK_FAILED"
  [[ "$(getenforce 2>/dev/null || true)" == Enforcing ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ "$(findmnt -n -T "$mount" -o TARGET 2>/dev/null || true)" == "$mount" ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ "$(findmnt -n -T "$mount" -o FSTYPE 2>/dev/null || true)" == "${KVM_DATA_FSTYPE:-ext4}" ]] || return "$EXIT_POSTCHECK_FAILED"

  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" list --all >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-info "$pool" | grep -Eq '^State:[[:space:]]+running' || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-info "$pool" | grep -Eq '^Autostart:[[:space:]]+yes' || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-info "$network" | grep -Eq '^Active:[[:space:]]+yes' || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" net-info "$network" | grep -Eq '^Autostart:[[:space:]]+yes' || return "$EXIT_POSTCHECK_FAILED"

  firewall-cmd --state >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  [[ "$(firewall-cmd --get-zone-of-interface="${KVM_BRIDGE_NAME:-virbr50}" 2>/dev/null || true)" == "${KVM_FIREWALLD_ZONE:-libvirt}" ]] || return "$EXIT_POSTCHECK_FAILED"
  sudo systemctl is-active --quiet fedora-gnome-custom-kvm-guard.service || return "$EXIT_POSTCHECK_FAILED"
  sudo nft list table inet "${KVM_NFT_TABLE:-fedora_gnome_custom_kvm}" >/dev/null || return "$EXIT_POSTCHECK_FAILED"

  for cmd in virt-install virt-clone qemu-img virt-manager virt-viewer remote-viewer swtpm swtpm_setup virtiofsd osinfo-query guestfish virt-filesystems; do
    command_exists "$cmd" || return "$EXIT_POSTCHECK_FAILED"
  done
  find /usr/share -maxdepth 5 -type f \( -name 'OVMF_CODE*.fd' -o -path '*/qemu/firmware/*.json' \) -print -quit 2>/dev/null | grep -q . || return "$EXIT_POSTCHECK_FAILED"
  osinfo-query os >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"

  printf '%s\n' 'KVM CONTRACT READY — live guest traffic proof remains a separate on-machine certification step'
}

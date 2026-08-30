#!/usr/bin/env bash
set -Eeuo pipefail
kvm_vm_profiles_validate() {
  [[ "${VM_PROFILE_DEFAULT_NETWORK:-}" == "${KVM_NETWORK_NAME:-devops-nat}" ]] || return 1
  [[ "${VM_PROFILE_DEFAULT_POOL:-}" == "${KVM_POOL_NAME:-devops-data}" ]] || return 1
  is_true "${VM_PROFILE_GPU_PASSTHROUGH_ALLOWED:-false}" && return 1
  [[ "${UBUNTU_SERVER_NAME:-}" == "ubuntu-devops" && "${UBUNTU_SERVER_RELEASE:-}" == "26.04" ]] || return 1
  [[ "${UBUNTU_SERVER_VCPU:-}" == "6" && "${UBUNTU_SERVER_RAM_MB:-}" == "16384" && "${UBUNTU_SERVER_DISK_GB:-}" == "160" ]] || return 1
  [[ "${UBUNTU_SERVER_NETWORK:-}" == "${KVM_NETWORK_NAME:-devops-nat}" && "${UBUNTU_SERVER_DISK_BUS:-}" == "virtio" && "${UBUNTU_SERVER_NETWORK_MODEL:-}" == "virtio" ]] || return 1
  is_true "${UBUNTU_SERVER_CLOUD_INIT:-false}" && is_true "${UBUNTU_SERVER_CLOUD_IMAGE_REQUIRED:-false}" || return 1
  is_true "${UBUNTU_SERVER_QEMU_GUEST_AGENT:-false}" && is_true "${UBUNTU_SERVER_VIRTIO_RNG:-false}" && is_true "${UBUNTU_SERVER_MEMORY_BALLOON:-false}" || return 1
  [[ "${UBUNTU_SERVER_USERNAME:-}" == "mathias" && "${UBUNTU_SERVER_PASSWORD_MODE:-}" == "runtime-prompt" ]] || return 1
  [[ -r "$REPO_ROOT/${UBUNTU_SERVER_BOOTSTRAP_SCRIPT:-guest/ubuntu-devops/bootstrap-devops.sh}" && -r "$REPO_ROOT/${UBUNTU_SERVER_VERIFY_SCRIPT:-guest/ubuntu-devops/verify-devops.sh}" ]] || return 1
  [[ "${WINDOWS11_NAME:-}" == "windows-11" && "${WINDOWS11_VCPU:-}" == "4" && "${WINDOWS11_RAM_MB:-}" == "12288" && "${WINDOWS11_DISK_GB:-}" == "128" ]] || return 1
  [[ "${WINDOWS11_FIRMWARE:-}" == "uefi-secureboot" && "${WINDOWS11_TPM_VERSION:-}" == "2.0" && "${WINDOWS11_TPM_BACKEND:-}" == "emulator" ]] || return 1
  [[ "${WINDOWS11_DISK_BUS:-}" == "virtio" && "${WINDOWS11_NETWORK_MODEL:-}" == "virtio" && "${WINDOWS11_NETWORK:-}" == "${KVM_NETWORK_NAME:-devops-nat}" ]] || return 1
  is_true "${WINDOWS11_REQUIRE_INSTALL_ISO:-false}" && is_true "${WINDOWS11_REQUIRE_VIRTIO_DRIVERS:-false}" || return 1
  is_true "${WINDOWS11_QEMU_GUEST_AGENT:-false}" && is_true "${WINDOWS11_VIRTIO_RNG:-false}" && is_true "${WINDOWS11_MEMORY_BALLOON:-false}" && is_true "${WINDOWS11_SPICE_CHANNEL:-false}" || return 1
  [[ -r "$REPO_ROOT/${WINDOWS11_INTEGRATION_SCRIPT:-guest/windows-11/configure-guest-integration.ps1}" ]] || return 1
  [[ -z "${FEDORA_VM_NAME:-}" ]] || return 1
}
kvm_vm_profiles_precheck() { is_true "${ENABLE_KVM:-true}" || return 0; kvm_vm_profiles_validate || { log_error KVM 'VM profile configuration violates the completed two-guest virtualization contract'; return "$EXIT_PRECHECK_FAILED"; }; }
kvm_vm_profiles_plan() { echo 'Two explicit guests: Ubuntu 26.04 and Windows 11 with VirtIO disk/network, QEMU Guest Agent channel, RNG, memory balloon, measured T705 I/O profile; Windows also gets UEFI Secure Boot, TPM 2.0 and SPICE channel.'; }
kvm_vm_profiles_apply() { :; }
kvm_vm_profiles_postcheck() { is_true "${DRY_RUN:-true}" && return 0; is_true "${ENABLE_KVM:-true}" || return 0; kvm_vm_profiles_validate || return "$EXIT_POSTCHECK_FAILED"; command_exists cloud-localds && command_exists openssl; }

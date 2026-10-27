#!/usr/bin/env bash
set -Eeuo pipefail
kvm_vm_profiles_validate() {
  [[ "${VM_PROFILE_DEFAULT_NETWORK:-}" == "${KVM_NETWORK_NAME:-devops-nat}" ]] || return 1
  [[ "${VM_PROFILE_DEFAULT_POOL:-}" == "${KVM_POOL_NAME:-devops-data}" ]] || return 1
  is_true "${VM_PROFILE_GPU_PASSTHROUGH_ALLOWED:-false}" && return 1
  [[ "${ROCKY_SERVER_NAME:-}" == "rocky-devops" && "${ROCKY_SERVER_RELEASE:-}" == "10.2" ]] || return 1
  [[ "${ROCKY_SERVER_VCPU:-}" == "6" && "${ROCKY_SERVER_RAM_MB:-}" == "16384" && "${ROCKY_SERVER_DISK_GB:-}" == "160" ]] || return 1
  [[ "${ROCKY_SERVER_NETWORK:-}" == "${KVM_NETWORK_NAME:-devops-nat}" && "${ROCKY_SERVER_DISK_BUS:-}" == "virtio" && "${ROCKY_SERVER_NETWORK_MODEL:-}" == "virtio" ]] || return 1
  is_true "${ROCKY_SERVER_CLOUD_INIT:-false}" && is_true "${ROCKY_SERVER_CLOUD_IMAGE_REQUIRED:-false}" || return 1
  is_true "${ROCKY_SERVER_QEMU_GUEST_AGENT:-false}" && is_true "${ROCKY_SERVER_VIRTIO_RNG:-false}" && is_true "${ROCKY_SERVER_MEMORY_BALLOON:-false}" || return 1
  [[ "${ROCKY_SERVER_USERNAME:-}" == "mathias" && "${ROCKY_SERVER_PASSWORD_MODE:-}" == "runtime-prompt" ]] || return 1
  [[ -r "$REPO_ROOT/${ROCKY_SERVER_BOOTSTRAP_SCRIPT:-guest/rocky-devops/bootstrap-devops.sh}" && -r "$REPO_ROOT/${ROCKY_SERVER_VERIFY_SCRIPT:-guest/rocky-devops/verify-devops.sh}" ]] || return 1
  [[ -z "${FEDORA_VM_NAME:-}" ]] || return 1
}
kvm_vm_profiles_precheck() { is_true "${ENABLE_KVM:-true}" || return 0; kvm_vm_profiles_validate || { log_error KVM 'VM profile configuration violates the Rocky Linux virtualization contract'; return "$EXIT_PRECHECK_FAILED"; }; }
kvm_vm_profiles_plan() { echo 'One explicit guest: Rocky Linux 10.2 with UEFI, VirtIO disk/network, QEMU Guest Agent channel, RNG, memory balloon and measured T705 I/O profile.'; }
kvm_vm_profiles_apply() { :; }
kvm_vm_profiles_postcheck() { is_true "${DRY_RUN:-true}" && return 0; is_true "${ENABLE_KVM:-true}" || return 0; kvm_vm_profiles_validate || return "$EXIT_POSTCHECK_FAILED"; command_exists cloud-localds && command_exists openssl; }

#!/usr/bin/env bash
set -Eeuo pipefail

kvm_vm_profiles_validate() {
  [[ "${VM_PROFILE_DEFAULT_NETWORK:-}" == "${KVM_NETWORK_NAME:-devops-nat}" ]] || return 1
  [[ "${VM_PROFILE_DEFAULT_POOL:-}" == "${KVM_POOL_NAME:-devops-data}" ]] || return 1
  is_true "${VM_PROFILE_GPU_PASSTHROUGH_ALLOWED:-false}" && return 1

  [[ "${UBUNTU_SERVER_NAME:-}" == "ubuntu-devops" ]] || return 1
  [[ "${UBUNTU_SERVER_RELEASE:-}" == "26.04" ]] || return 1
  [[ "${UBUNTU_SERVER_VCPU:-}" == "6" ]] || return 1
  [[ "${UBUNTU_SERVER_RAM_MB:-}" == "16384" ]] || return 1
  [[ "${UBUNTU_SERVER_DISK_GB:-}" == "160" ]] || return 1
  [[ "${UBUNTU_SERVER_NETWORK:-}" == "${KVM_NETWORK_NAME:-devops-nat}" ]] || return 1
  [[ "${UBUNTU_SERVER_DISK_BUS:-}" == "virtio" ]] || return 1
  [[ "${UBUNTU_SERVER_NETWORK_MODEL:-}" == "virtio" ]] || return 1
  is_true "${UBUNTU_SERVER_CLOUD_INIT:-false}" || return 1
  is_true "${UBUNTU_SERVER_CLOUD_IMAGE_REQUIRED:-false}" || return 1
  is_true "${UBUNTU_SERVER_VIRTIOFS:-false}" || return 1
  [[ "${UBUNTU_SERVER_USERNAME:-}" == "mathias" ]] || return 1
  [[ "${UBUNTU_SERVER_PASSWORD_MODE:-}" == "runtime-prompt" ]] || return 1
  [[ "${UBUNTU_SERVER_VIRTIOFS_SOURCE:-}" == "${KVM_DATA_MOUNT:-/data}/libvirt/shared" ]] || return 1
  [[ "${UBUNTU_SERVER_VIRTIOFS_TAG:-}" == "hostshare" ]] || return 1
  [[ "${UBUNTU_SERVER_VIRTIOFS_MOUNT:-}" == "/mnt/hostshare" ]] || return 1
  [[ -r "$REPO_ROOT/${UBUNTU_SERVER_BOOTSTRAP_SCRIPT:-guest/ubuntu-devops/bootstrap-devops.sh}" ]] || return 1
  [[ -r "$REPO_ROOT/${UBUNTU_SERVER_VERIFY_SCRIPT:-guest/ubuntu-devops/verify-devops.sh}" ]] || return 1

  [[ "${WINDOWS11_NAME:-}" == "windows-11" ]] || return 1
  [[ "${WINDOWS11_VCPU:-}" == "4" ]] || return 1
  [[ "${WINDOWS11_RAM_MB:-}" == "12288" ]] || return 1
  [[ "${WINDOWS11_DISK_GB:-}" == "128" ]] || return 1
  [[ "${WINDOWS11_NETWORK:-}" == "${KVM_NETWORK_NAME:-devops-nat}" ]] || return 1
  [[ "${WINDOWS11_FIRMWARE:-}" == "uefi-secureboot" ]] || return 1
  [[ "${WINDOWS11_TPM_VERSION:-}" == "2.0" ]] || return 1
  [[ "${WINDOWS11_TPM_BACKEND:-}" == "emulator" ]] || return 1
  [[ "${WINDOWS11_DISK_BUS:-}" == "virtio" ]] || return 1
  [[ "${WINDOWS11_NETWORK_MODEL:-}" == "virtio" ]] || return 1
  is_true "${WINDOWS11_REQUIRE_INSTALL_ISO:-false}" || return 1
  is_true "${WINDOWS11_REQUIRE_VIRTIO_DRIVERS:-false}" || return 1
  is_true "${WINDOWS11_VIRTIOFS:-false}" && return 1

  [[ -z "${FEDORA_VM_NAME:-}" ]] || return 1
}

kvm_vm_profiles_precheck() {
  is_true "${ENABLE_KVM:-true}" || return 0
  kvm_vm_profiles_validate || {
    log_error KVM 'VM profile configuration violates the final two-guest virtualization contract'
    return "$EXIT_PRECHECK_FAILED"
  }
}

kvm_vm_profiles_plan() {
  cat <<'EOF'
ON-DEMAND VM PROFILES:
- Ubuntu Server 26.04 LTS (ubuntu-devops): 6 vCPU, 16 GiB RAM, 160 GiB qcow2, UEFI, VirtIO, cloud-init, SSH, VirtioFS and dedicated DevOps bootstrap
- Windows 11: 4 vCPU, 12 GiB RAM, 128 GiB qcow2, UEFI Secure Boot, TPM 2.0 swtpm, VirtIO disk/network and SPICE
- only these two reference guests are maintained; no Fedora guest profile
- no profile autostarts by default
- no profile uses VFIO or Intel Arc passthrough
- profile definitions never create VMs during workstation APPLY; creation is an explicit operator action
EOF
}

kvm_vm_profiles_apply() { :; }

kvm_vm_profiles_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KVM:-true}" || return 0
  kvm_vm_profiles_validate || return "$EXIT_POSTCHECK_FAILED"
  if is_true "${KVM_REQUIRE_VIRTIOFS:-true}" && ! command_exists virtiofsd; then
    log_error KVM 'VirtioFS is required by ubuntu-devops but virtiofsd is unavailable'
    return "$EXIT_POSTCHECK_FAILED"
  fi
  command_exists cloud-localds || return "$EXIT_POSTCHECK_FAILED"
  command_exists openssl || return "$EXIT_POSTCHECK_FAILED"
}

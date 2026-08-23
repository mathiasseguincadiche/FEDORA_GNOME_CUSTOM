#!/usr/bin/env bash
set -Eeuo pipefail

kvm_vm_profiles_validate() {
  [[ "${VM_PROFILE_DEFAULT_NETWORK:-}" == "${KVM_NETWORK_NAME:-devops-nat}" ]] || return 1
  [[ "${VM_PROFILE_DEFAULT_POOL:-}" == "${KVM_POOL_NAME:-devops-data}" ]] || return 1
  if is_true "${VM_PROFILE_GPU_PASSTHROUGH_ALLOWED:-false}"; then return 1; fi
  [[ "${UBUNTU_SERVER_NETWORK:-}" == "${KVM_NETWORK_NAME:-devops-nat}" ]] || return 1
  [[ "${FEDORA_VM_NETWORK:-}" == "${KVM_NETWORK_NAME:-devops-nat}" ]] || return 1
  [[ "${WINDOWS11_NETWORK:-}" == "${KVM_NETWORK_NAME:-devops-nat}" ]] || return 1
  [[ "${WINDOWS11_FIRMWARE:-}" == "uefi-secureboot" ]] || return 1
  [[ "${WINDOWS11_TPM_VERSION:-}" == "2.0" ]] || return 1
  [[ "${WINDOWS11_TPM_BACKEND:-}" == "emulator" ]] || return 1
  [[ "${UBUNTU_SERVER_DISK_BUS:-}" == "virtio" && "${FEDORA_VM_DISK_BUS:-}" == "virtio" && "${WINDOWS11_DISK_BUS:-}" == "virtio" ]] || return 1
  [[ "${UBUNTU_SERVER_NETWORK_MODEL:-}" == "virtio" && "${FEDORA_VM_NETWORK_MODEL:-}" == "virtio" && "${WINDOWS11_NETWORK_MODEL:-}" == "virtio" ]] || return 1
}

kvm_vm_profiles_precheck() {
  is_true "${ENABLE_KVM:-true}" || return 0
  kvm_vm_profiles_validate || { log_error KVM 'VM profile configuration violates the virtualization contract'; return "$EXIT_PRECHECK_FAILED"; }
}

kvm_vm_profiles_plan() {
  cat <<'EOF'
ON-DEMAND VM PROFILES:
- Ubuntu Server 26.04 LTS: primary DevOps/Ops lab, UEFI, cloud-init, VirtIO, VirtioFS, SSH-oriented, no graphical console requirement
- Fedora 44 lab: UEFI, VirtIO, SPICE/virtio-gpu, VirtioFS, 3D disabled by default for stability
- Windows 11: UEFI Secure Boot, TPM 2.0 swtpm, VirtIO disk/network, SPICE console, external VirtIO driver media required
- no profile autostarts by default
- no profile uses VFIO or Intel Arc passthrough
- profile definitions do not create VMs during workstation APPLY
EOF
}

kvm_vm_profiles_apply() { :; }

kvm_vm_profiles_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KVM:-true}" || return 0
  kvm_vm_profiles_validate || return "$EXIT_POSTCHECK_FAILED"
  if is_true "${KVM_REQUIRE_VIRTIOFS:-true}" && ! command_exists virtiofsd; then
    log_error KVM 'VirtioFS is required by Linux VM profiles but virtiofsd is unavailable'
    return "$EXIT_POSTCHECK_FAILED"
  fi
}

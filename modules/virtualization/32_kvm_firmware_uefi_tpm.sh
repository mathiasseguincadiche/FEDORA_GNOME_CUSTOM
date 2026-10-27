#!/usr/bin/env bash
set -Eeuo pipefail

kvm_firmware_find_ovmf() {
  find /usr/share -maxdepth 5 -type f \( -name 'OVMF_CODE*.fd' -o -name '*OVMF*.json' -o -path '*/qemu/firmware/*.json' \) -print 2>/dev/null
}

kvm_firmware_precheck() {
  is_true "${ENABLE_KVM:-true}" || return 0
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"
}

kvm_firmware_plan() {
  cat <<'EOF'
UEFI / TPM PLAN:
- use Fedora edk2-ovmf firmware metadata for x86_64 UEFI guests
- use UEFI for the Rocky Linux profile; Secure Boot is not required by this guest
- retain generic swtpm tooling for optional Linux TPM experiments; Rocky does not require it
- never share TPM state between guests
- keep any guest NVRAM/TPM state in the owner's separate manual exports, outside Borg
EOF
}

kvm_firmware_apply() {
  # Packages are installed by kvm.stack. This module intentionally performs no firmware mutation.
  :
}

kvm_firmware_postcheck() {
  local firmware
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KVM:-true}" || return 0
  if ! command_exists swtpm || ! command_exists swtpm_setup; then return "$EXIT_POSTCHECK_FAILED"; fi
  firmware="$(kvm_firmware_find_ovmf)"
  [[ -n "$firmware" ]] || { log_error KVM 'OVMF firmware/descriptor not found'; return "$EXIT_POSTCHECK_FAILED"; }
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" domcapabilities 2>/dev/null | grep -Eqi 'loader|firmware' || {
    log_error KVM 'libvirt domain capabilities do not expose firmware support'
    return "$EXIT_POSTCHECK_FAILED"
  }
  swtpm --version >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
}

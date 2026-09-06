#!/usr/bin/env bash

# Runtime driver contract for the exact Golden Workstation hardware.
# The contract validates actual kernel bindings and rejects silent fallbacks.

driver_contract_sysfs_root() { printf '%s\n' "${HARDWARE_SYSFS_ROOT:-/sys}"; }

driver_contract_normalize_hex() {
  printf '%s' "$1" | sed -E 's/^0x//' | tr '[:upper:]' '[:lower:]'
}

driver_contract_pci_driver_for_id() {
  local wanted_vendor wanted_device root dev vendor device
  wanted_vendor="$(driver_contract_normalize_hex "$1")"
  wanted_device="$(driver_contract_normalize_hex "$2")"
  root="$(driver_contract_sysfs_root)"
  for dev in "$root"/bus/pci/devices/*; do
    [[ -r "$dev/vendor" && -r "$dev/device" ]] || continue
    vendor="$(driver_contract_normalize_hex "$(<"$dev/vendor")")"
    device="$(driver_contract_normalize_hex "$(<"$dev/device")")"
    [[ "$vendor" == "$wanted_vendor" && "$device" == "$wanted_device" ]] || continue
    [[ -L "$dev/driver" ]] || return 1
    basename "$(readlink -f "$dev/driver")"
    return 0
  done
  return 1
}

driver_contract_module_intree() {
  local module="$1" intree
  intree="$(modinfo -F intree "$module" 2>/dev/null | head -n1 || true)"
  [[ "$intree" =~ ^([Yy]|1|yes|YES)$ ]]
}

driver_contract_wifi_locked_driver() {
  local lock
  lock="$(hardware_platform_wifi_lock_path)"
  [[ -s "$lock" ]] || return 1
  awk -F= '$1=="driver" {print $2; exit}' "$lock"
}

driver_contract_nvme_expected_bound() {
  local root ctrl model driver count=0
  root="$(driver_contract_sysfs_root)"
  for ctrl in "$root"/class/nvme/nvme*; do
    [[ -d "$ctrl" && -r "$ctrl/model" ]] || continue
    model="$(tr -d '\000' < "$ctrl/model" | sed -E 's/[[:space:]]+$//')"
    [[ "$model" == "${EXPECTED_NVME_MODEL:-CT1000T705SSD3}" ]] || continue
    [[ -L "$ctrl/device/driver" ]] || return 1
    driver="$(basename "$(readlink -f "$ctrl/device/driver")")"
    [[ "$driver" == nvme ]] || return 1
    ((count+=1))
  done
  (( count == ${EXPECTED_NVME_COUNT:-2} ))
}

driver_contract_lspci_block_uses() {
  local pattern="$1" driver="$2"
  lspci -Dnnk 2>/dev/null | awk -v RS='' -v pattern="$pattern" -v driver="$driver" '
    $0 ~ pattern && $0 ~ ("Kernel driver in use:[[:space:]]*" driver "([[:space:]]|$)") { found=1 }
    END { exit !found }
  '
}

driver_contract_no_foreign_gpu_stack() {
  ! lsmod 2>/dev/null | awk '{print $1}' | grep -Eq '^nvidia(_|$)' || return 1
  if command -v rpm >/dev/null 2>&1; then
    ! rpm -q akmod-nvidia xorg-x11-drv-nvidia >/dev/null 2>&1 || return 1
  fi
}

driver_contract_fingerprint_payload() {
  local gpu wifi module state
  gpu="$(driver_contract_pci_driver_for_id "${EXPECTED_GPU_PCI_VENDOR:-8086}" "${EXPECTED_GPU_PCI_DEVICE:-e20b}" 2>/dev/null || printf missing)"
  wifi="$(driver_contract_wifi_locked_driver 2>/dev/null || printf missing)"
  printf 'gpu=%s\n' "$gpu"
  printf 'wifi=%s\n' "$wifi"
  printf 'lan=%s\n' "${EXPECTED_LAN_DRIVER:-r8169}"
  printf 'nvme=%s\n' "$(driver_contract_nvme_expected_bound && printf nvme || printf invalid)"
  for module in xe r8169 nvme xhci_hcd snd_usb_audio nct6683 ${wifi:+$wifi}; do
    state=external
    driver_contract_module_intree "$module" && state=intree
    printf 'module:%s=%s\n' "$module" "$state"
  done
}

driver_contract_fingerprint() { driver_contract_fingerprint_payload | sha256sum | awk '{print $1}'; }

driver_contract_validate() {
  runtime_is_baremetal || return 1
  hardware_platform_validate_dmi || return 1

  local gpu_driver wifi_driver module
  gpu_driver="$(driver_contract_pci_driver_for_id "${EXPECTED_GPU_PCI_VENDOR:-8086}" "${EXPECTED_GPU_PCI_DEVICE:-e20b}" 2>/dev/null || true)"
  [[ "$gpu_driver" == "${EXPECTED_GPU_KERNEL_DRIVER:-xe}" ]] || return 1

  hardware_platform_wifi_lock_valid || return 1
  wifi_driver="$(driver_contract_wifi_locked_driver 2>/dev/null || true)"
  [[ -n "$wifi_driver" ]] || return 1

  driver_contract_lspci_block_uses 'Ethernet controller' "${EXPECTED_LAN_DRIVER:-r8169}" || return 1
  driver_contract_lspci_block_uses 'USB controller' xhci_hcd || return 1
  driver_contract_nvme_expected_bound || return 1

  for module in xe r8169 nvme xhci_hcd snd_usb_audio nct6683 "$wifi_driver"; do
    driver_contract_module_intree "$module" || return 1
  done

  driver_contract_no_foreign_gpu_stack
}

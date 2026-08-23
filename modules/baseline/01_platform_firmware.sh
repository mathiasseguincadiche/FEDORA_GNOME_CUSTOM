#!/usr/bin/env bash
set -Eeuo pipefail
baseline_platform_firmware_precheck() { [[ -r /sys/class/dmi/id/board_name && -r /sys/class/dmi/id/bios_version ]]; }
baseline_platform_firmware_plan() { echo 'Inventory motherboard, BIOS/UEFI, Secure Boot, kernel and IOMMU without changing firmware settings.'; }
baseline_platform_firmware_apply() { log_info BASELINE 'read-only platform inventory'; }
baseline_platform_firmware_postcheck() {
  {
    echo "board=$(baseline_hw_value /sys/class/dmi/id/board_name)"
    echo "bios=$(baseline_hw_value /sys/class/dmi/id/bios_version)"
    echo "bios_date=$(baseline_hw_value /sys/class/dmi/id/bios_date)"
    echo "kernel=$(uname -r)"
    if [[ -d /sys/kernel/iommu_groups ]]; then echo 'iommu=present'; else echo 'iommu=not-detected'; fi
    if command_exists mokutil; then mokutil --sb-state 2>&1 || true; fi
  } >> "$MODULE_LOG"
}

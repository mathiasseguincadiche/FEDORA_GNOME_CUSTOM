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
    [[ -d /sys/kernel/iommu_groups ]] && echo 'iommu=present' || echo 'iommu=not-detected'
    command_exists mokutil && mokutil --sb-state 2>&1 || true
  } >> "$MODULE_LOG"
}

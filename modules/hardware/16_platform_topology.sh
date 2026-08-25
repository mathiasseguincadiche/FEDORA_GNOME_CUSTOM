#!/usr/bin/env bash
set -Eeuo pipefail
hardware_topology_precheck() { command_exists lspci && command_exists nvme && [[ -r /sys/class/dmi/id/board_name ]]; }
hardware_topology_plan() { echo 'Certify the MSI B850M MORTAR WIFI topology, UEFI/Secure Boot, AMD virtualization/IOMMU, Arc B580 ReBAR endpoint and both Crucial T705 endpoints without changing firmware settings.'; }
hardware_topology_apply() { :; }
hardware_topology_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  [[ "$(< /sys/class/dmi/id/board_name)" == *"$EXPECTED_MOTHERBOARD"* ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ -d /sys/firmware/efi ]] || return "$EXIT_POSTCHECK_FAILED"
  if is_true "${PLATFORM_REQUIRE_SECURE_BOOT:-true}"; then command_exists mokutil && mokutil --sb-state 2>/dev/null | grep -qi 'SecureBoot enabled' || return "$EXIT_POSTCHECK_FAILED"; fi
  if is_true "${PLATFORM_REQUIRE_AMD_VIRTUALIZATION:-true}"; then grep -qw svm /proc/cpuinfo || return "$EXIT_POSTCHECK_FAILED"; fi
  if is_true "${PLATFORM_REQUIRE_IOMMU_FOR_KVM:-true}"; then find /sys/kernel/iommu_groups -mindepth 1 -maxdepth 1 -type d -print -quit 2>/dev/null | grep -q . || return "$EXIT_POSTCHECK_FAILED"; fi
  lspci -nn -d "${EXPECTED_GPU_PCI_VENDOR}:${EXPECTED_GPU_PCI_DEVICE}" | grep -qi "$EXPECTED_GPU" || return "$EXIT_POSTCHECK_FAILED"
  local nvme_count
  nvme_count="$(for f in /sys/class/nvme/nvme*/model; do [[ -r "$f" ]] && grep -Fx "$EXPECTED_NVME_MODEL" "$f"; done | wc -l)"
  (( nvme_count == EXPECTED_NVME_COUNT )) || return "$EXIT_POSTCHECK_FAILED"
}

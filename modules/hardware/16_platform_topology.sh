#!/usr/bin/env bash
set -Eeuo pipefail
hardware_topology_precheck() { command_exists lspci && command_exists nvme && [[ -r /sys/class/dmi/id/board_name ]]; }
hardware_topology_plan() { echo 'Certify the MSI B850M MORTAR WIFI topology, UEFI boot, Arc B580 PCIe endpoint and both Crucial T705 endpoints without changing firmware settings.'; }
hardware_topology_apply() { :; }
hardware_topology_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  [[ "$(< /sys/class/dmi/id/board_name)" == *"$EXPECTED_MOTHERBOARD"* ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ -d /sys/firmware/efi ]] || return "$EXIT_POSTCHECK_FAILED"
  lspci -nn -d "${EXPECTED_GPU_PCI_VENDOR}:${EXPECTED_GPU_PCI_DEVICE}" | grep -qi "$EXPECTED_GPU" || return "$EXIT_POSTCHECK_FAILED"
  local nvme_count
  nvme_count="$(for f in /sys/class/nvme/nvme*/model; do [[ -r "$f" ]] && grep -Fx "$EXPECTED_NVME_MODEL" "$f"; done | wc -l)"
  (( nvme_count == EXPECTED_NVME_COUNT )) || return "$EXIT_POSTCHECK_FAILED"
}

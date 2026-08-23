#!/usr/bin/env bash
set -Eeuo pipefail

graphics_find_gpu() {
  local dev vendor device driver
  for dev in /sys/bus/pci/devices/*; do
    [[ -r "$dev/vendor" && -r "$dev/device" ]] || continue
    vendor="$(normalize_hex "$(<"$dev/vendor")")"; device="$(normalize_hex "$(<"$dev/device")")"
    [[ "$vendor" == "$(normalize_hex "$EXPECTED_GPU_PCI_VENDOR")" && "$device" == "$(normalize_hex "$EXPECTED_GPU_PCI_DEVICE")" ]] || continue
    [[ -L "$dev/driver" ]] || return 1
    driver="$(basename "$(readlink -f "$dev/driver")")"
    [[ "$driver" == "$EXPECTED_GPU_KERNEL_DRIVER" ]] || return 1
    printf '%s\n' "$dev"; return 0
  done
  return 1
}

hardware_graphics_precheck() { is_true "${ALLOW_FORCE_PROBE:-false}" && { log_error HARDWARE 'force_probe policy must remain disabled'; return "$EXIT_PRECHECK_FAILED"; }; graphics_find_gpu >/dev/null; }
hardware_graphics_plan() { echo 'Use Fedora kernel/firmware/Mesa only; validate Arc B580 8086:e20b bound to xe, Vulkan, VA-API and GPU/DRM errors. No force_probe or third-party GPU repo.'; }
hardware_graphics_apply() { install_manifest_packages HARDWARE "$REPO_ROOT/manifests/packages-hardware.txt"; }
hardware_graphics_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  graphics_find_gpu >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  vulkaninfo --summary 2>/dev/null | grep -Eqi 'Intel|B580|Battlemage' || log_warn HARDWARE 'Vulkan probe unavailable in current session; run graphics-doctor inside GNOME'
  vainfo >/dev/null 2>&1 || log_warn HARDWARE 'VA-API probe unavailable in current session'
  if journalctl -k -b --no-pager | grep -Eqi '\b(xe|drm)\b.*(gpu hang|reset|wedged|fault|error)'; then log_warn HARDWARE 'current boot contains xe/DRM warning signatures; run graphics-doctor'; fi
}

#!/usr/bin/env bash
set -Eeuo pipefail

system_firmware_precheck() { command_exists dnf; }

system_firmware_plan() {
  echo 'Install Fedora firmware plus AMD CPU microcode and Intel Arc firmware explicitly; inventory fwupd only, never flash firmware automatically.'
}

system_firmware_apply() {
  local -a packages=(fwupd linux-firmware)
  if grep -q 'AuthenticAMD' /proc/cpuinfo 2>/dev/null; then
    packages+=(amd-ucode-firmware)
  elif grep -q 'GenuineIntel' /proc/cpuinfo 2>/dev/null; then
    packages+=(microcode_ctl)
  fi
  if lspci -Dn 2>/dev/null | grep -Eqi '030[02]:[[:space:]]+8086:e20b'; then
    packages+=(intel-gpu-firmware)
  fi
  run_mutating SYSTEM sudo dnf -y install "${packages[@]}"
}

system_firmware_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  command_exists fwupdmgr || return "$EXIT_POSTCHECK_FAILED"
  if grep -q 'AuthenticAMD' /proc/cpuinfo 2>/dev/null; then
    rpm -q amd-ucode-firmware >/dev/null || return "$EXIT_POSTCHECK_FAILED"
    [[ -r /sys/devices/system/cpu/microcode/version ]] || log_warn SYSTEM 'CPU microcode version sysfs node is unavailable'
  fi
  if lspci -Dn 2>/dev/null | grep -Eqi '030[02]:[[:space:]]+8086:e20b'; then
    rpm -q intel-gpu-firmware >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  fi
  if journalctl -k -b --no-pager 2>/dev/null | grep -Eqi 'firmware.*(failed to load|not found|direct-loading.*failed)'; then
    log_warn SYSTEM 'kernel journal contains firmware load failures; run firmware-doctor'
  fi
  fwupdmgr get-devices >/dev/null 2>&1 || log_warn SYSTEM 'fwupd device inventory unavailable; no firmware flash attempted'
}

#!/usr/bin/env bash
set -Eeuo pipefail
system_firmware_precheck() { command_exists dnf; }
system_firmware_plan() { echo 'Install Fedora firmware/microcode tooling; do not flash firmware automatically.'; }
system_firmware_apply() { run_mutating SYSTEM sudo dnf -y install fwupd microcode_ctl linux-firmware; }
system_firmware_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  command_exists fwupdmgr || return "$EXIT_POSTCHECK_FAILED"
  fwupdmgr get-devices >/dev/null 2>&1 || log_warn SYSTEM 'fwupd device inventory unavailable; no firmware flash attempted'
}

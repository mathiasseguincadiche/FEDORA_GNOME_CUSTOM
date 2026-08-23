#!/usr/bin/env bash
set -Eeuo pipefail
hardware_peripherals_precheck() { command_exists dnf; }
hardware_peripherals_plan() { echo 'Inventory USB, Logitech Brio 100, networking and PipeWire/WirePlumber without applying power or USB quirks.'; }
hardware_peripherals_apply() { run_mutating HARDWARE sudo dnf -y install usbutils pciutils ethtool v4l-utils pipewire-utils; }
hardware_peripherals_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  { echo '[usb]'; lsusb; echo '[video]'; v4l2-ctl --list-devices 2>&1 || true; echo '[network]'; ip -br link; echo '[audio]'; wpctl status 2>&1 || true; } > "$REPORT_ROOT/$RUN_ID-peripherals.txt"
}

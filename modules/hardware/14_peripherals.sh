#!/usr/bin/env bash
set -Eeuo pipefail
hardware_peripherals_precheck() { command_exists dnf; }
hardware_peripherals_plan() { echo 'Install and certify 5G LAN, Wi-Fi/6GHz, Bluetooth, ALC4080/PipeWire and xHCI tooling without applying unsafe power/USB quirks.'; }
hardware_peripherals_apply() { run_mutating HARDWARE sudo dnf -y install usbutils pciutils ethtool v4l-utils pipewire-utils iw bluez alsa-utils; }
hardware_peripherals_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  { echo '[usb]'; lsusb; echo '[video]'; v4l2-ctl --list-devices 2>&1 || true; echo '[network]'; ip -br link; echo '[audio]'; wpctl status 2>&1 || true; } > "$REPORT_ROOT/$RUN_ID-peripherals.txt"
  "$REPO_ROOT/diagnostics/hardware-components-doctor" --quiet
}

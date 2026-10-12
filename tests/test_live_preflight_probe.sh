#!/usr/bin/env bash
# Unit checks for hardware-specific parsers without bypassing Live-only guards.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/lib/live_preflight_probe.sh"
pci_good='0000:00:14.0 USB controller [0c03]: Intel Corporation Something [8086:1234]
        Kernel driver in use: xhci_hcd
0000:03:00.0 VGA compatible controller [0300]: Intel Corporation Battlemage [Arc B580] [8086:e20b] (rev 05)
        Subsystem: Intel Corporation Device [8086:1111]
        Kernel driver in use: xe
        Kernel modules: xe
0000:04:00.0 Ethernet controller [0200]: Realtek Controller [10ec:8126]
        Kernel driver in use: r8169'
[[ "$(live_b580_binding_status "$pci_good")" == bound ]]
[[ "$(live_b580_binding_status "${pci_good/Kernel driver in use: xe/Kernel driver in use: i915}")" == driver-unverified ]]
[[ "$(live_b580_binding_status "${pci_good/Kernel driver in use: xe/Kernel modules: xe}")" == driver-unverified ]]
[[ "$(live_b580_binding_status '0000:04:00.0 Ethernet controller [0200]: Realtek [10ec:8126]')" == absent ]]
nvme_good='nvme0n1 nvme CT1000T705SSD3
nvme1n1 nvme CT1000T705SSD3'
[[ "$(live_t705_status "$nvme_good")" == match ]]
[[ "$(live_t705_status 'nvme0n1 nvme CT1000T705SSD3')" == count-mismatch ]]
[[ "$(live_t705_status 'nvme0n1 nvme CT1000T705SSD3
nvme1n1 nvme CT1000T700SSD3')" == model-mismatch ]]
[[ "$(live_t705_status 'nvme0n1 nvme CT1000T705SSD3
nvme1n1 nvme')" == model-unverified ]]
echo 'Live Fedora 45 hardware parser contract: PASS'

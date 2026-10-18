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
live_expected_cpu_model 'AMD Ryzen 7 7700 8-Core Processor'
if live_expected_cpu_model 'AMD Ryzen 7 7700X 8-Core Processor'; then
  echo 'incorrectly accepted Ryzen 7700X' >&2; exit 1
fi
if live_expected_cpu_model 'AMD Ryzen 7 77000 8-Core Processor'; then
  echo 'incorrectly accepted unrelated Ryzen SKU' >&2; exit 1
fi
nvme_good='nvme0n1 nvme CT1000T705SSD3
nvme1n1 nvme CT1000T705SSD3'
[[ "$(live_t705_status "$nvme_good")" == match ]]
[[ "$(live_t705_status 'nvme0n1 nvme CT1000T705SSD3')" == count-mismatch ]]
[[ "$(live_t705_status 'nvme0n1 nvme CT1000T705SSD3
nvme1n1 nvme CT1000T700SSD3')" == model-mismatch ]]
[[ "$(live_t705_status 'nvme0n1 nvme CT1000T705SSD3
nvme1n1 nvme')" == model-unverified ]]
# Five checks must never silently certify missing human evidence.
[[ "$(live_manual_status o)" == PASS ]]
[[ "$(live_manual_status oui)" == PASS ]]
[[ "$(live_manual_status N)" == FAIL ]]
[[ "$(live_manual_status non)" == FAIL ]]
[[ "$(live_manual_status '?')" == NOT_TESTED ]]
[[ "$(live_manual_status '')" == NOT_TESTED ]]
[[ "$(live_manual_status 'perhaps')" == NOT_TESTED ]]
[[ "$(live_go_decision 0 0)" == GO ]]
[[ "$(live_go_decision 1 0)" == NO-GO ]]
[[ "$(live_go_decision 1 1)" == NO-GO ]]
[[ "$(live_go_decision 0 1)" == A_VERIFIER ]]
[[ "$(live_go_decision 0 2)" == A_VERIFIER ]]
# The real Live-only entrypoint stays guarded, with no fake Live boot.
live_script="$(cat "$ROOT/diagnostics/live-preflight.sh")"
[[ "$live_script" == *'if (( EUID == 0 ))'* ]]
[[ "$live_script" == *'REFUSED: no evidence of a Live environment'* ]]
[[ "$live_script" == *'manual_check display'* ]]
[[ "$live_script" == *'manual_check network'* ]]
[[ "$live_script" == *'[[ "$verdict" == GO ]]'* ]]
[[ "$live_script" != *'sudo '* ]]
[[ "$live_script" != *'mount '* ]]
[[ "$live_script" != *'mkfs'* ]]
echo 'Live Fedora 45 hardware and five-check GO/NO-GO contract: PASS'

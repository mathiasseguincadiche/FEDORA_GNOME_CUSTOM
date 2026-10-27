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
# Missing human evidence is never inferred from hardware inventory.
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

# Native running GNOME matters: installed packages, a VM or an unreadable probe
# must not certify a native Live session. No OS/runtime is faked for the CLI.
[[ "$(live_session_status 45 'GNOME Shell 51.0' wayland 1 true)" == PASS ]]
[[ "$(live_session_status 45 'GNOME Shell 51.0' wayland 0 true)" == FAIL ]]
[[ "$(live_session_status 45 'GNOME Shell 51.0' wayland 2 true)" == NOT_TESTED ]]
[[ "$(live_session_status 45 'GNOME Shell 51.0' wayland 1 false)" == FAIL ]]
[[ "$(live_session_status 45 'GNOME Shell 51.0' wayland 1 unknown)" == NOT_TESTED ]]
[[ "$(live_session_status 44 'GNOME Shell 50.5' wayland 1 true)" == FAIL ]]
[[ "$(live_session_status 45 'GNOME Shell 51.0' x11 1 true)" == FAIL ]]
[[ "$(live_session_status 45 '' wayland 1 true)" == NOT_TESTED ]]
[[ "$(live_session_status '' 'GNOME Shell 51.0' wayland 1 true)" == NOT_TESTED ]]
[[ "$(live_session_status 45 'GNOME Shell 50.5' wayland 2 unknown)" == FAIL ]]

# Current mode is distinct from an advertised/preferred mode. This fixture
# follows plain gdctl show; --verbose intentionally has no Current-mode marker.
display_good='Monitors:
└──Monitor DP-1 (ASUS)
    ├──Current mode
    │   └──2560x1440@239.970
Logical monitors:
└──Logical monitor #1'
display_preferred="${display_good/Current mode/Preferred mode}"
[[ "$(live_current_display_modes "$display_good")" == 2560x1440@239.970 ]]
[[ -z "$(live_current_display_modes "$display_preferred")" ]]
[[ "$(live_display_mode_status '2560x1440@239.970')" == PASS ]]
[[ "$(live_display_mode_status '2560x1440@60')" == FAIL ]]
[[ "$(live_display_mode_status '1920x1080@240')" == FAIL ]]
[[ "$(live_display_mode_status '')" == NOT_TESTED ]]
[[ "$(live_display_mode_status 'unparseable mode')" == NOT_TESTED ]]
[[ "$(live_display_mode_status '2560x1440@240.0.5')" == NOT_TESTED ]]
[[ "$(live_display_mode_status $'2560x1440@240\n1920x1080@60')" == NOT_TESTED ]]
audio_good='Audio
 ├─ Devices:
 │  30. Audio Device
 ├─ Sinks:
 │ * 40. Speakers [vol: 1.00]
 ├─ Sources:
 │ * 41. Microphone [vol: 0.50]
 └─ Streams:
Video
 └─ Sources:
     90. Camera'
[[ "$(live_audio_device_counts "$audio_good")" == '1 1' ]]
[[ "$(live_audio_device_counts 'Audio')" == '0 0' ]]
[[ "$(live_audio_device_counts "${audio_good/41. Microphone/No microphone}")" == '1 0' ]]
[[ "$(live_bluetooth_controller_count 'Controller AA:BB:CC:DD:EE:FF Host [default]')" == 1 ]]
[[ "$(live_bluetooth_controller_count 'Controller invalid Host')" == 0 ]]
[[ "$(live_usb_device_count 'Bus 001 Device 001: ID 1d6b:0002 Linux Foundation root hub')" == 1 ]]
[[ "$(live_usb_device_count 'Bus 001 Device 001: ID invalid USB')" == 0 ]]
nm_good=$'enp5s0:ethernet:connected\nwlp6s0:wifi:disconnected\nlo:loopback:connected (externally)'
[[ "$(live_connected_interface "$nm_good" ethernet)" == enp5s0 ]]
[[ -z "$(live_connected_interface "$nm_good" wifi)" ]]
resume_good=$'kernel: PM: suspend entry (s2idle)\nkernel: PM: suspend exit'
[[ "$(live_suspend_cycle_status PASS "$resume_good")" == PASS ]]
[[ "$(live_suspend_cycle_status PASS 'PM: suspend exit')" == NOT_TESTED ]]
[[ "$(live_suspend_cycle_status PASS $'PM: suspend exit\nPM: suspend entry')" == NOT_TESTED ]]
[[ "$(live_suspend_cycle_status NOT_TESTED "$resume_good")" == NOT_TESTED ]]
[[ "$(live_suspend_cycle_status FAIL "$resume_good")" == FAIL ]]

# Exercise actual collection/report functions with captured-output command
# doubles. Never call the main Live guard with fabricated host identity.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
source "$ROOT/diagnostics/live-preflight.sh"
VERSION_ID=45; XDG_SESSION_TYPE=wayland
gnome-shell() { echo 'GNOME Shell 51.0'; }
gdbus() { echo '(true,)'; }
systemd-detect-virt() { return "${fixture_native_rc:-1}"; }
lspci() { [[ "$*" == -Dnnk ]]; printf '%s\n' "$pci_good"; }
lsblk() { [[ "$*" == '-dn -o NAME,TRAN,MODEL' ]]; printf '%s\n' "$nvme_good"; }
gdctl() { [[ "$*" == show ]]; printf '%s\n' "${fixture_display:-$display_good}"; }
nmcli() { [[ "$*" == '-t -f DEVICE,TYPE,STATE device status' ]]; printf '%s\n' "${fixture_network:-$nm_good}"; }
curl() {
  printf '%s\n' "$*" >> "$tmp/https.calls"
  [[ "${fixture_lan_fail:-false}" != true || "$*" != *'--interface enp5s0'* ]]
}
wpctl() { [[ "$*" == status ]]; printf '%s\n' "$audio_good"; }
bluetoothctl() { [[ "$*" == list ]]; echo 'Controller AA:BB:CC:DD:EE:FF Host [default]'; }
timeout() { [[ "$1" == 6 ]]; shift; "$@"; }
lsusb() { echo 'Bus 001 Device 001: ID 1d6b:0002 Linux Foundation root hub'; }
journalctl() { printf '%s\n' "${fixture_resume:-$resume_good}"; }
live_manual_answer() {
  case "$1" in
    display) echo "${fixture_visual:-PASS}" ;;
    display_mode) echo "${fixture_mode_answer:-NOT_TESTED}" ;;
    network) echo NOT_TESTED ;;
    audio_output) echo "${fixture_audio:-${fixture_manual:-NOT_TESTED}}" ;;
    *) echo "${fixture_manual:-NOT_TESTED}" ;;
  esac
}
fixture_report() {
  local expected="$1" result=0
  (
    live_report_init
    live_identity_checks
    live_display_checks
    live_network_checks
    live_peripheral_checks
    live_suspend_check
    live_report_finish
  ) > "$tmp/report" 2> "$tmp/prompts" || result=$?
  [[ "$result" == "$expected" ]] || { cat "$tmp/report" >&2; exit 1; }
}
row_is() { awk -F '\t' -v id="$1" -v state="$2" '$2==id && $1==state {found=1} END {exit !found}' "$tmp/report"; }
decision_is() { grep -Fq $'DECISION\t'"$1"$'\t' "$tmp/report"; }
fixture_report 0
decision_is GO
row_is session PASS; row_is storage PASS; row_is display_mode PASS
row_is lan PASS; row_is wifi NOT_TESTED
row_is audio_devices PASS; row_is audio_output NOT_TESTED; row_is microphone NOT_TESTED
row_is bluetooth_controller PASS; row_is bluetooth NOT_TESTED
row_is usb_devices PASS; row_is usb NOT_TESTED; row_is suspend_resume NOT_TESTED
grep -Fq 'installed system NOT_CERTIFIED' "$tmp/report"
grep -Fq -- '--interface enp5s0' "$tmp/https.calls"
[[ "$(awk -F '\t' '$1~/^(PASS|FAIL|NOT_TESTED)$/ {count++; seen[$2]++} END {for(id in seen) if(seen[id]!=1) exit 1; print count}' "$tmp/report")" == 16 ]]
diff <(live_check_catalog | cut -f1) <(awk -F '\t' '$1~/^(PASS|FAIL|NOT_TESTED)$/ {print $2}' "$tmp/report")

fixture_visual=NOT_TESTED fixture_report 1
decision_is A_VERIFIER
fixture_native_rc=0 fixture_report 1
row_is session FAIL; decision_is NO-GO
fixture_native_rc=2 fixture_report 1
row_is session NOT_TESTED; decision_is A_VERIFIER
fixture_display="${display_good/239.970/60}" fixture_report 1
row_is display_mode FAIL; decision_is NO-GO
fixture_display="$display_preferred" fixture_report 1
row_is display_mode NOT_TESTED; decision_is A_VERIFIER
fixture_display="$display_preferred" fixture_mode_answer=PASS fixture_report 0
row_is display_mode PASS
grep -Fq 'requirement=required evidence=manual;' "$tmp/report"

# A functioning Wi-Fi path cannot hide an observed LAN failure. A failed
# optional playback attempt also blocks GO despite all mandatory checks passing.
fixture_network=$'enp5s0:ethernet:connected\nwlp6s0:wifi:connected' fixture_lan_fail=true fixture_report 1
row_is lan FAIL; row_is wifi PASS; row_is network PASS; decision_is NO-GO
fixture_audio=FAIL fixture_report 1
row_is audio_output FAIL; decision_is NO-GO
fixture_manual=PASS fixture_report 0
row_is microphone PASS; row_is bluetooth PASS; row_is usb PASS; row_is suspend_resume PASS
fixture_manual=PASS fixture_resume='No suspend records available' fixture_report 0
row_is suspend_resume NOT_TESTED

# A missing result stays explicit and prevents GO if it is mandatory. Detail
# sanitization preserves exactly three columns even with multiline tool output.
result=0
(
  live_report_init
  emit PASS gpu $'fixture\twith\nnewlines\r'
  live_report_finish
) > "$tmp/report" || result=$?
[[ "$result" == 1 ]]
row_is display NOT_TESTED; decision_is A_VERIFIER
[[ "$(awk -F '\t' '$2=="gpu" {print NF}' "$tmp/report")" == 3 ]]
[[ "$(bash "$ROOT/diagnostics/live-preflight.sh" --catalog | wc -l)" == 17 ]]
# The real Live-only entrypoint stays guarded, with no fake Live boot.
live_script="$(cat "$ROOT/diagnostics/live-preflight.sh")"
[[ "$live_script" == *'if (( EUID == 0 ))'* ]]
[[ "$live_script" == *'REFUSED: no evidence of a Live environment'* ]]
[[ "$live_script" == *'manual_check display'* ]]
[[ "$live_script" == *'manual_check network'* ]]
[[ "$live_script" == *"[[ \"\$verdict\" == GO ]]"* ]]
[[ "$live_script" != *'sudo '* ]]
[[ "$live_script" != *'mount '* ]]
[[ "$live_script" != *'mkfs'* ]]
[[ "$live_script" != *'systemctl suspend'* ]]
[[ "$live_script" != *'engine_bootstrap'* ]]
[[ "$live_script" == *'systemd-detect-virt --quiet'* ]]
echo 'Native Live qualification parsers, evidence provenance and GO/NO-GO policy: PASS (fixtures only)'

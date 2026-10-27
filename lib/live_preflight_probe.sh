#!/usr/bin/env bash
# Pure parsing helpers for the Fedora Live preflight. No reads/writes or mutations
# happen when this file is sourced; each helper receives captured command output.

# Version 2 contract. IDs are stable; inventory and functional observations are
# separate. Every observed FAIL blocks GO, including optional checks.
live_check_catalog() {
  printf '%s\n' \
    $'session\trequired\tautomatic' \
    $'gpu\trequired\tautomatic' \
    $'storage\trequired\tautomatic' \
    $'display_mode\trequired\tautomatic-or-manual' \
    $'display\trequired\tmanual' \
    $'network\trequired\tautomatic-or-manual' \
    $'lan\toptional\tautomatic' \
    $'wifi\toptional\tautomatic' \
    $'audio_devices\toptional\tautomatic' \
    $'audio_output\toptional\tmanual' \
    $'microphone\toptional\tmanual' \
    $'bluetooth_controller\toptional\tautomatic' \
    $'bluetooth\toptional\tmanual' \
    $'usb_devices\toptional\tautomatic' \
    $'usb\toptional\tmanual' \
    $'suspend_resume\toptional\tmanual-and-kernel'
}

live_check_requirement() {
  live_check_catalog | awk -F '\t' -v id="$1" '$1==id {print $2; found=1} END {exit !found}'
}

live_session_status() {
  local release="$1" shell="$2" session="$3" native_rc="$4" shell_running="$5"
  if [[ ( -n "$release" && "$release" != 45 ) || "$native_rc" == 0 || "$shell_running" == false ||
        ( -n "$shell" && ! "$shell" =~ ^GNOME[[:space:]]Shell[[:space:]]51([.[:space:]]|$) ) ||
        ( -n "$session" && "$session" != wayland ) ]]; then
    printf 'FAIL\n'
  elif [[ -z "$release" || -z "$shell" || -z "$session" || "$native_rc" != 1 || "$shell_running" != true ]]; then
    printf 'NOT_TESTED\n'
  else
    printf 'PASS\n'
  fi
}

# Plain gdctl show distinguishes Current from Preferred; --verbose lists modes.
live_current_display_modes() {
  awk '
    /Current mode/ {current=1; next}
    current {
      current=0
      if (match($0, /[0-9]+x[0-9]+@[0-9.]+/)) print substr($0,RSTART,RLENGTH)
    }
  ' <<<"$1"
}

live_display_mode_status() {
  awk '
    NF {
      if ($0 !~ /^[0-9]+x[0-9]+@[0-9]+([.][0-9]+)?$/) invalid++
      count++; split($0,a,"@"); rate=a[2]+0
      if (a[1]=="2560x1440" && a[2] ~ /^[0-9]+([.][0-9]+)?$/ && rate>=239 && rate<=241) good++
    }
    END {
      if (count!=1 || invalid) print "NOT_TESTED"
      else if (good==1) print "PASS"
      else print "FAIL"
    }
  ' <<<"$1"
}

live_connected_interface() {
  # nmcli -t -f DEVICE,TYPE,STATE device status; disconnected is not a test.
  awk -F: -v kind="$2" '$2==kind && $3=="connected" {print $1; exit}' <<<"$1"
}

live_audio_device_counts() {
  # wpctl status: graph headers or a playback sink do not prove microphone input.
  awk '
    /^[[:space:]]*Audio[[:space:]]*$/ {audio=1; next}
    /^[[:space:]]*(Video|Settings)[[:space:]]*$/ {audio=0}
    audio && /Sinks:/ {section="sink"; next}
    audio && /Sources:/ {section="source"; next}
    audio && /(Devices:|Filters:|Streams:)/ {section=""; next}
    audio && /[0-9]+\.[[:space:]]/ {
      if(section=="sink") sinks++
      if(section=="source") sources++
    }
    END {printf "%d %d\n",sinks,sources}
  ' <<<"$1"
}

live_bluetooth_controller_count() {
  awk '/^Controller / {n=split($2,a,":"); good=(n==6); for(i=1;i<=n;i++) if(a[i] !~ /^[[:xdigit:]][[:xdigit:]]$/) good=0; count+=good} END {print count+0}' <<<"$1"
}

live_usb_device_count() {
  awk '/^Bus [0-9]+ Device [0-9]+: ID / {n=split($6,a,":"); if(n==2 && length(a[1])==4 && length(a[2])==4 && $6 ~ /^[[:xdigit:]]+:[[:xdigit:]]+$/) count++} END {print count+0}' <<<"$1"
}

live_suspend_cycle_status() {
  local observed="$1" journal="$2"
  case "$observed" in
    FAIL) printf 'FAIL\n' ;;
    PASS)
      awk '/PM: suspend entry/ {entered=1} entered && /PM: suspend exit/ {resumed=1} END {print resumed ? "PASS" : "NOT_TESTED"}' <<<"$journal"
      ;;
    *) printf 'NOT_TESTED\n' ;;
  esac
}
live_b580_pci_block() {
  awk '
    /^[[:xdigit:]]+:[[:xdigit:]]+:[[:xdigit:]]+\.[0-7][[:space:]]/ {
      if (found) exit
      found = (tolower($0) ~ /\[8086:e20b\]/)
    }
    found { print }
  '
}

live_b580_binding_status() {
  local block
  block="$(live_b580_pci_block <<<"$1")"
  if [[ -z "$block" ]]; then
    printf 'absent\n'
  elif grep -Eq '^[[:space:]]*Kernel driver in use:[[:space:]]*xe[[:space:]]*$' <<<"$block"; then
    printf 'bound\n'
  else
    # "Kernel modules: xe" alone is NOT evidence of an active xe binding.
    printf 'driver-unverified\n'
  fi
}

live_expected_cpu_model() {
  # Reject nearby SKUs such as Ryzen 7 7700X: the workstation targets 7700.
  [[ "$1" =~ AMD[[:space:]]Ryzen[[:space:]]7[[:space:]]7700([^[:alnum:]]|$) ]]
}

live_t705_status() {
  # Input: lsblk -dn -o NAME,TRAN,MODEL (the model may contain spaces).
  awk '
    tolower($2) == "nvme" {
      total++
      if (toupper($0) ~ /CT[0-9]+T705SSD[0-9]+/) t705++
      if (NF < 3) unknown++
    }
    END {
      if (total != 2) print "count-mismatch"
      else if (t705 == 2) print "match"
      else if (unknown > 0) print "model-unverified"
      else print "model-mismatch"
    }
  ' <<<"$1"
}

# Manual checks are never inferred from lspci or a connection icon.
live_manual_status() {
  local answer="$1"
  case "$answer" in
    o|O|oui|Oui|OUI|y|Y|yes|Yes|YES) printf 'PASS\n';;
    n|N|non|Non|NON|no|No|NO) printf 'FAIL\n';;
    *) printf 'NOT_TESTED\n';;
  esac
}

# Argument 1 counts every FAIL; argument 2 only missing mandatory evidence.
live_go_decision() {
  local failed="$1" untested="$2"
  if (( failed > 0 )); then
    printf 'NO-GO\n'
  elif (( untested > 0 )); then
    printf 'A_VERIFIER\n'
  else
    printf 'GO\n'
  fi
}

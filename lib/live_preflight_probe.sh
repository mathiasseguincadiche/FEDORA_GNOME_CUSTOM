#!/usr/bin/env bash
# Pure parsing helpers for the Fedora Live preflight. No reads/writes or mutations
# happen when this file is sourced; each helper receives captured command output.
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

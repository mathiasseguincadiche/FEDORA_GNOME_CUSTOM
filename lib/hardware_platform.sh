#!/usr/bin/env bash

hardware_platform_sysfs_root() { printf '%s\n' "${HARDWARE_SYSFS_ROOT:-/sys}"; }
hardware_platform_dmi_root() { printf '%s/class/dmi/id\n' "$(hardware_platform_sysfs_root)"; }
hardware_platform_state_dir() { printf '%s/hardware\n' "$STATE_ROOT"; }
hardware_platform_wifi_lock_path() { printf '%s/wifi-identity.env\n' "$(hardware_platform_state_dir)"; }

hardware_platform_value() {
  local path="$1" fallback="${2:-unknown}"
  if [[ -r "$path" ]]; then
    tr -d '\000' < "$path" | head -n1
  else
    printf '%s\n' "$fallback"
  fi
}

hardware_platform_board_vendor() { hardware_platform_value "$(hardware_platform_dmi_root)/board_vendor"; }
hardware_platform_board_name() { hardware_platform_value "$(hardware_platform_dmi_root)/board_name"; }
hardware_platform_bios_vendor() { hardware_platform_value "$(hardware_platform_dmi_root)/bios_vendor"; }
hardware_platform_bios_version() { hardware_platform_value "$(hardware_platform_dmi_root)/bios_version"; }
hardware_platform_bios_date() { hardware_platform_value "$(hardware_platform_dmi_root)/bios_date"; }

hardware_platform_validate_dmi() {
  runtime_is_baremetal || return 1
  local board_vendor board_name bios_vendor bios_version bios_date
  board_vendor="$(hardware_platform_board_vendor)"
  board_name="$(hardware_platform_board_name)"
  bios_vendor="$(hardware_platform_bios_vendor)"
  bios_version="$(hardware_platform_bios_version)"
  bios_date="$(hardware_platform_bios_date)"

  [[ "$board_vendor" =~ (Micro-Star|MSI) ]] || return 1
  [[ "$board_name" == *"${EXPECTED_MOTHERBOARD:-MAG B850M MORTAR WIFI}"* || "$board_name" == *MS-7E61* ]] || return 1
  [[ "$bios_vendor" =~ (American[[:space:]]Megatrends|AMI) ]] || return 1
  [[ -n "$bios_version" && "$bios_version" != unknown && "$bios_version" != 'Default string' ]] || return 1
  [[ -n "$bios_date" && "$bios_date" != unknown && "$bios_date" != 'Default string' ]] || return 1
}

hardware_platform_cpufreq_policy() {
  local root policy
  root="$(hardware_platform_sysfs_root)/devices/system/cpu/cpufreq"
  for policy in "$root"/policy*; do
    [[ -d "$policy" ]] || continue
    printf '%s\n' "$policy"
    return 0
  done
  return 1
}

hardware_platform_cpu_scaling_driver() {
  local policy
  policy="$(hardware_platform_cpufreq_policy)" || return 1
  hardware_platform_value "$policy/scaling_driver"
}

hardware_platform_cpu_pstate_status() {
  local root
  root="$(hardware_platform_sysfs_root)"
  hardware_platform_value "$root/devices/system/cpu/amd_pstate/status"
}

hardware_platform_cpu_boost_value() {
  local root policy node
  root="$(hardware_platform_sysfs_root)"
  policy="$(hardware_platform_cpufreq_policy 2>/dev/null || true)"
  for node in \
    "$root/devices/system/cpu/cpufreq/boost" \
    "${policy:+$policy/boost}" \
    "$root/devices/system/cpu/cpu0/cpufreq/boost" \
    "${policy:+$policy/cpb}"; do
    [[ -n "$node" && -r "$node" ]] || continue
    hardware_platform_value "$node"
    return 0
  done
  return 1
}

hardware_platform_validate_cpu_power() {
  runtime_is_baremetal || return 1
  lscpu 2>/dev/null | grep -Fq "${EXPECTED_CPU:-AMD Ryzen 7 7700}" || return 1
  local driver status boost
  driver="$(hardware_platform_cpu_scaling_driver 2>/dev/null || true)"
  status="$(hardware_platform_cpu_pstate_status 2>/dev/null || true)"
  boost="$(hardware_platform_cpu_boost_value 2>/dev/null || true)"
  case "$driver" in
    amd-pstate|amd-pstate-epp|amd_pstate|amd_pstate_epp) ;;
    *) return 1 ;;
  esac
  [[ "$status" =~ ^(active|passive|guided)$ ]] || return 1
  [[ "$boost" == 1 ]]
}

hardware_platform_wifi_block() {
  lspci -Dnnk 2>/dev/null | awk 'BEGIN{RS=""} /Network controller|Wireless/ {print; exit}'
}

hardware_platform_wifi_identity() {
  local block header bdf pci_id driver
  block="$(hardware_platform_wifi_block)"
  [[ -n "$block" ]] || return 1
  header="$(head -n1 <<<"$block")"
  bdf="${header%% *}"
  pci_id="$(grep -Eo '\[[0-9a-fA-F]{4}:[0-9a-fA-F]{4}\]' <<<"$header" | tail -n1 | tr -d '[]' | tr '[:upper:]' '[:lower:]')"
  driver="$(awk -F: '/Kernel driver in use:/ {gsub(/^[ \t]+/,"",$2); print $2; exit}' <<<"$block")"
  [[ -n "$bdf" && "$pci_id" =~ ^[0-9a-f]{4}:[0-9a-f]{4}$ && -n "$driver" ]] || return 1
  printf 'bdf=%s\npci_id=%s\ndriver=%s\n' "$bdf" "$pci_id" "$driver"
}

hardware_platform_wifi_identity_value() {
  local key="$1" identity
  identity="$(hardware_platform_wifi_identity)" || return 1
  awk -F= -v key="$key" '$1==key {print $2; exit}' <<<"$identity"
}

hardware_platform_enroll_wifi_identity() {
  runtime_is_baremetal || return "$EXIT_SECURITY_BLOCK"
  hardware_platform_validate_dmi || return "$EXIT_PRECHECK_FAILED"
  local identity path bdf pci_id driver
  identity="$(hardware_platform_wifi_identity)" || return "$EXIT_PRECHECK_FAILED"
  bdf="$(awk -F= '$1=="bdf" {print $2}' <<<"$identity")"
  pci_id="$(awk -F= '$1=="pci_id" {print $2}' <<<"$identity")"
  driver="$(awk -F= '$1=="driver" {print $2}' <<<"$identity")"
  path="$(hardware_platform_wifi_lock_path)"
  mkdir -p "$(dirname "$path")"
  {
    printf 'schema=1\n'
    printf 'board_name=%s\n' "$(hardware_platform_board_name)"
    printf 'bdf=%s\n' "$bdf"
    printf 'pci_id=%s\n' "$pci_id"
    printf 'driver=%s\n' "$driver"
    printf 'enrolled_utc=%s\n' "$(date -u +%FT%TZ)"
  } | evidence_atomic_write "$path" 0600
  printf '%s\n' "$path"
}

hardware_platform_wifi_lock_valid() {
  runtime_is_baremetal || return 1
  local path current_pci current_driver locked_pci locked_driver locked_board
  path="$(hardware_platform_wifi_lock_path)"
  [[ -s "$path" ]] || return 1
  grep -Fxq 'schema=1' "$path" || return 1
  current_pci="$(hardware_platform_wifi_identity_value pci_id 2>/dev/null || true)"
  current_driver="$(hardware_platform_wifi_identity_value driver 2>/dev/null || true)"
  locked_pci="$(awk -F= '$1=="pci_id" {print $2; exit}' "$path")"
  locked_driver="$(awk -F= '$1=="driver" {print $2; exit}' "$path")"
  locked_board="$(awk -F= '$1=="board_name" {sub(/^board_name=/,""); print; exit}' "$path")"
  [[ "$locked_board" == "$(hardware_platform_board_name)" ]] || return 1
  [[ -n "$current_pci" && "$current_pci" == "$locked_pci" ]] || return 1
  [[ -n "$current_driver" && "$current_driver" == "$locked_driver" ]]
}

hardware_platform_hwmon_chip_dir() {
  local root hwmon name
  root="$(hardware_platform_sysfs_root)/class/hwmon"
  for hwmon in "$root"/hwmon*; do
    [[ -d "$hwmon" ]] || continue
    name="$(hardware_platform_value "$hwmon/name" '')"
    case "$name" in
      nct6683|nct6686|nct6687) printf '%s\n' "$hwmon"; return 0 ;;
    esac
  done
  return 1
}

hardware_platform_hwmon_counts() {
  local chip file value temp_count=0 fan_count=0 fan_live=0
  chip="$(hardware_platform_hwmon_chip_dir)" || return 1
  for file in "$chip"/temp*_input; do
    [[ -r "$file" ]] || continue
    value="$(<"$file")"
    [[ "$value" =~ ^-?[0-9]+$ ]] || continue
    (( value > -40000 && value < 130000 )) && ((temp_count+=1))
  done
  for file in "$chip"/fan*_input; do
    [[ -r "$file" ]] || continue
    value="$(<"$file")"
    [[ "$value" =~ ^[0-9]+$ ]] || continue
    ((fan_count+=1))
    (( value > 0 )) && ((fan_live+=1))
  done
  printf 'temp=%d\nfan=%d\nfan_live=%d\n' "$temp_count" "$fan_count" "$fan_live"
}

hardware_platform_validate_hwmon() {
  runtime_is_baremetal || return 1
  local counts temp_count fan_count fan_live
  counts="$(hardware_platform_hwmon_counts)" || return 1
  temp_count="$(awk -F= '$1=="temp" {print $2}' <<<"$counts")"
  fan_count="$(awk -F= '$1=="fan" {print $2}' <<<"$counts")"
  fan_live="$(awk -F= '$1=="fan_live" {print $2}' <<<"$counts")"
  (( temp_count >= 1 && fan_count >= 1 && fan_live >= 1 ))
}

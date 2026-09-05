#!/usr/bin/env bash
# Hardware qualification helpers for the Golden Ryzen 7 7700 / Arc B580 profile.
# REPO_ROOT/STATE_ROOT/config are supplied by engine_bootstrap.
# shellcheck disable=SC2153

hardware_expected_gpu_bdf() {
  local dev vendor device expected_vendor expected_device
  expected_vendor="$(normalize_hex "${EXPECTED_GPU_PCI_VENDOR:-8086}")"
  expected_device="$(normalize_hex "${EXPECTED_GPU_PCI_DEVICE:-e20b}")"
  for dev in /sys/bus/pci/devices/*; do
    [[ -r "$dev/vendor" && -r "$dev/device" ]] || continue
    vendor="$(normalize_hex "$(<"$dev/vendor")")"
    device="$(normalize_hex "$(<"$dev/device")")"
    if [[ "$vendor" == "$expected_vendor" && "$device" == "$expected_device" ]]; then
      printf '%s\n' "${dev##*/}"
      return 0
    fi
  done
  return 1
}

hardware_pcie_speed_gts() {
  local raw="${1:-}"
  raw="${raw%% GT/s*}"
  raw="${raw// /}"
  [[ "$raw" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
  printf '%s\n' "$raw"
}

hardware_pcie_link_caps() {
  local bdf="$1" dev="/sys/bus/pci/devices/$1" current_speed current_width max_speed max_width
  [[ -d "$dev" ]] || return 1
  current_speed="$(baseline_hw_value "$dev/current_link_speed" unknown)"
  current_width="$(baseline_hw_value "$dev/current_link_width" unknown)"
  max_speed="$(baseline_hw_value "$dev/max_link_speed" unknown)"
  max_width="$(baseline_hw_value "$dev/max_link_width" unknown)"
  printf 'bdf=%s\ncurrent_link_speed=%s\ncurrent_link_width=%s\nmax_link_speed=%s\nmax_link_width=%s\n' \
    "$bdf" "$current_speed" "$current_width" "$max_speed" "$max_width"
}

hardware_pci_largest_bar_bytes() {
  local bdf="$1" file="/sys/bus/pci/devices/$1/resource" start end flags size max=0
  [[ -r "$file" ]] || return 1
  while read -r start end flags; do
    [[ "$start" =~ ^0x[0-9a-fA-F]+$ && "$end" =~ ^0x[0-9a-fA-F]+$ ]] || continue
    (( end >= start )) || continue
    size=$((16#${end#0x} - 16#${start#0x} + 1))
    (( size > max )) && max=$size
  done < "$file"
  printf '%s\n' "$max"
}

hardware_b580_rebar_enabled() {
  local bdf report largest
  bdf="$(hardware_expected_gpu_bdf)" || return 1
  report="$(lspci -vv -s "$bdf" 2>/dev/null || true)"
  grep -Eqi 'Resizable BAR|Physical Resizable BAR' <<<"$report" || return 1
  largest="$(hardware_pci_largest_bar_bytes "$bdf" 2>/dev/null || printf 0)"
  [[ "$largest" =~ ^[0-9]+$ ]] || return 1
  (( largest >= 512 * 1024 * 1024 ))
}

hardware_b580_pcie_validate() {
  local bdf dev curw maxw maxs_num
  bdf="$(hardware_expected_gpu_bdf)" || return 1
  dev="/sys/bus/pci/devices/$bdf"
  [[ -L "$dev/driver" && "$(basename "$(readlink -f "$dev/driver")")" == "${EXPECTED_GPU_KERNEL_DRIVER:-xe}" ]] || return 1
  curw="$(baseline_hw_value "$dev/current_link_width" 0)"
  maxw="$(baseline_hw_value "$dev/max_link_width" 0)"
  maxs_num="$(hardware_pcie_speed_gts "$(baseline_hw_value "$dev/max_link_speed" 0)" 2>/dev/null || printf 0)"
  [[ "$curw" =~ ^[0-9]+$ && "$maxw" =~ ^[0-9]+$ ]] || return 1
  (( curw >= 8 && maxw >= 8 )) || return 1
  awk -v s="$maxs_num" 'BEGIN { exit !(s >= 16.0) }' || return 1
  hardware_b580_rebar_enabled
}

hardware_b580_drm_card() {
  local bdf card
  bdf="$(hardware_expected_gpu_bdf)" || return 1
  for card in "/sys/bus/pci/devices/$bdf"/drm/card[0-9]*; do
    [[ -e "$card" ]] || continue
    basename "$card"
    return 0
  done
  return 1
}

hardware_b580_connected_connectors() {
  local card path mode_target="${DISPLAY_TARGET_WIDTH:-2560}x${DISPLAY_TARGET_HEIGHT:-1440}"
  card="$(hardware_b580_drm_card)" || return 1
  for path in /sys/class/drm/"$card"-*; do
    [[ -d "$path" && -r "$path/status" && -s "$path/edid" ]] || continue
    [[ "$(<"$path/status")" == connected ]] || continue
    if [[ -r "$path/modes" ]] && ! grep -Fxq "$mode_target" "$path/modes"; then
      continue
    fi
    printf '%s\n' "$path"
  done
}

hardware_display_profile_path() {
  printf '%s/hardware/display-profile.env\n' "$STATE_ROOT"
}

hardware_b580_capture_display_profile() {
  runtime_is_baremetal || return "$EXIT_SECURITY_BLOCK"
  local -a connectors=()
  local path bdf card edid marker user_marker payload
  mapfile -t connectors < <(hardware_b580_connected_connectors)
  (( ${#connectors[@]} == 1 )) || return 1
  path="${connectors[0]}"
  bdf="$(hardware_expected_gpu_bdf)" || return 1
  card="$(hardware_b580_drm_card)" || return 1
  edid="$(sha256sum "$path/edid" | awk '{print $1}')"
  [[ "$edid" =~ ^[0-9a-f]{64}$ ]] || return 1
  marker="$(hardware_display_profile_path)"
  user_marker="${XDG_STATE_HOME:-$HOME/.local/state}/fedora-gnome-custom/display-profile.env"
  payload="$(
    printf 'verdict=PASS\n'
    printf 'bdf=%s\n' "$bdf"
    printf 'card=%s\n' "$card"
    printf 'connector_path=%s\n' "$path"
    printf 'connector=%s\n' "$(basename "$path" | sed -E 's/^card[0-9]+-//')"
    printf 'edid_sha256=%s\n' "$edid"
    printf 'mode=%sx%s\n' "${DISPLAY_TARGET_WIDTH:-2560}" "${DISPLAY_TARGET_HEIGHT:-1440}"
    printf 'utc=%s\n' "$(date -u +%FT%TZ)"
  )"
  printf '%s\n' "$payload" | evidence_atomic_write "$marker" 0600
  printf '%s\n' "$payload" | evidence_atomic_write "$user_marker" 0600
}

hardware_b580_expected_edid_sha256() {
  local marker value
  marker="$(hardware_display_profile_path)"
  value="$(evidence_marker_value "$marker" edid_sha256 2>/dev/null || true)"
  if [[ "$value" =~ ^[0-9a-f]{64}$ ]]; then
    printf '%s\n' "$value"
    return 0
  fi
  return 1
}

hardware_b580_certified_connector() {
  local expected path hash count=0 match=''
  expected="$(hardware_b580_expected_edid_sha256)" || return 1
  while IFS= read -r path; do
    [[ -s "$path/edid" ]] || continue
    hash="$(sha256sum "$path/edid" | awk '{print $1}')"
    [[ "$hash" == "$expected" ]] || continue
    match="$path"
    ((count+=1))
  done < <(hardware_b580_connected_connectors)
  (( count == 1 )) || return 1
  printf '%s\n' "$match"
}

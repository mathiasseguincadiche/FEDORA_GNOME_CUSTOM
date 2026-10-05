#!/usr/bin/env bash
# Resolve enrolled endpoints from sysfs; USB card numbers may change at reboot.
peripheral_usb_identity() {
  local node="$1" root driver='' vendor product
  root="$(hardware_platform_sysfs_root)"
  node="$(readlink -f "$node")" || return 1
  while [[ "$node" == "$root"/* && "$node" != "$root" ]]; do
    if [[ -z "$driver" && -L "$node/driver" ]]; then driver="$(basename "$(readlink -f "$node/driver")")"; fi
    if [[ -r "$node/idVendor" && -r "$node/idProduct" ]]; then
      vendor="$(tr '[:upper:]' '[:lower:]' < "$node/idVendor")"
      product="$(tr '[:upper:]' '[:lower:]' < "$node/idProduct")"
      [[ "$vendor:$product" =~ ^[0-9a-f]{4}:[0-9a-f]{4}$ ]] || return 1
      printf 'usb_id=%s:%s\ndriver=%s\nproduct=%s\nserial=%s\n' "$vendor" "$product" "$driver" \
        "$(cat "$node/product" 2>/dev/null || true)" "$(cat "$node/serial" 2>/dev/null || true)"
      return 0
    fi
    node="$(dirname "$node")"
  done
  return 1
}
peripheral_identity() {
  local kind="$1" endpoint="$2" root data
  root="$(hardware_platform_sysfs_root)"
  case "$kind" in
    audio) [[ "$endpoint" =~ ^card[0-9]+$ ]] || return 1
      data="$(peripheral_usb_identity "$root/class/sound/$endpoint/device")" || return 1
      grep -Eq '^usb_id=0bda:[0-9a-f]{4}$' <<<"$data" || return 1
      grep -Fxq 'driver=snd_usb_audio' <<<"$data" || return 1;;
    camera) [[ "$endpoint" =~ ^video[0-9]+$ ]] || return 1
      data="$(peripheral_usb_identity "$root/class/video4linux/$endpoint/device")" || return 1
      grep -Eq '^usb_id=046d:[0-9a-f]{4}$' <<<"$data" || return 1
      grep -Fxq 'driver=uvcvideo' <<<"$data" || return 1
      grep -Eiq '^product=.*Brio[[:space:]]*100' <<<"$data" || return 1;;
    *) return 1;;
  esac
  printf '%s\n' "$data"
}
peripheral_lock_path() { printf '%s/hardware/%s-endpoint.env\n' "$STATE_ROOT" "$1"; }
peripheral_enroll() {
  runtime_is_baremetal && hardware_platform_validate_dmi || return 1
  local kind="$1" endpoint="$2" data path
  data="$(peripheral_identity "$kind" "$endpoint")" || return 1
  path="$(peripheral_lock_path "$kind")"; mkdir -p "$(dirname "$path")"
  { printf 'schema=1\nboard_name=%s\n' "$(hardware_platform_board_name)"; printf '%s\n' "$data"; } |
    evidence_atomic_write "$path" 0600
}
peripheral_resolve() {
  local kind="$1" root path node endpoint data saved pattern matches=()
  root="$(hardware_platform_sysfs_root)"; path="$(peripheral_lock_path "$kind")"
  [[ -s "$path" ]] && grep -Fxq 'schema=1' "$path" &&
    grep -Fxq "board_name=$(hardware_platform_board_name)" "$path" || return 1
  case "$kind" in audio) pattern="$root/class/sound/card"*;; camera) pattern="$root/class/video4linux/video"*;; *) return 1;; esac
  saved="$(sed -n '/^usb_id=/p; /^driver=/p; /^product=/p; /^serial=/p' "$path")"
  # Glob is intentionally expanded; sysfs paths contain no whitespace.
  # shellcheck disable=SC2086
  for node in $pattern; do
    [[ -e "$node/device" ]] || continue; endpoint="${node##*/}"
    data="$(peripheral_identity "$kind" "$endpoint")" || continue
    [[ "$data" == "$saved" ]] && matches+=("$endpoint")
  done
  if [[ "$kind" == camera ]]; then
    for endpoint in "${matches[@]}"; do
      v4l2-ctl -d "/dev/$endpoint" --all 2>/dev/null | grep -q 'Video Capture' || continue
      printf '%s\n' "$endpoint"; return 0
    done
    return 1
  fi
  ((${#matches[@]} == 1)) || return 1
  printf '%s\n' "${matches[0]}"
}

peripheral_resolve_camera_mic() {
  local root path usb serial node data matches=()
  root="$(hardware_platform_sysfs_root)"; path="$(peripheral_lock_path camera)"
  [[ -s "$path" ]] || return 1
  usb="$(sed -n 's/^usb_id=//p' "$path")"; serial="$(sed -n 's/^serial=//p' "$path")"
  for node in "$root"/class/sound/card*; do
    [[ -e "$node/device" ]] || continue
    data="$(peripheral_usb_identity "$node/device")" || continue
    grep -Fxq "usb_id=$usb" <<<"$data" && grep -Fxq "serial=$serial" <<<"$data" &&
      grep -Fxq 'driver=snd_usb_audio' <<<"$data" || continue
    matches+=("${node##*/}")
  done
  ((${#matches[@]} == 1)) || return 1
  printf '%s\n' "${matches[0]}"
}

peripheral_wifi_phy() {
  local bdf="$1" root phy
  root="$(hardware_platform_sysfs_root)"
  for phy in "$root"/class/ieee80211/phy*; do
    [[ -e "$phy/device" && "$(basename "$(readlink -f "$phy/device")")" == "$bdf" ]] || continue
    printf '%s\n' "${phy##*/}"; return 0
  done
  return 1
}

#!/usr/bin/env bash
set -Eeuo pipefail

command -v ffmpeg >/dev/null || { echo 'ffmpeg missing' >&2; exit 1; }
device="${VAAPI_DRM_DEVICE:-auto}"
if [[ "$device" == auto ]]; then
  device=''
  for node in /sys/class/drm/renderD*; do
    [[ -e "$node/device/vendor" && -e "$node/device/device" ]] || continue
    vendor="$(tr '[:upper:]' '[:lower:]' < "$node/device/vendor")"
    devid="$(tr '[:upper:]' '[:lower:]' < "$node/device/device")"
    if [[ "$vendor" == 0x8086 && "$devid" == 0xe20b ]]; then
      device="/dev/dri/$(basename "$node")"; break
    fi
  done
fi
[[ -n "$device" && -e "$device" ]] || { echo 'Arc B580 render node not found' >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
common_in=(-f lavfi -i 'testsrc2=size=128x72:rate=30' -t 1 -an)
va_filter='format=nv12,hwupload'

encode_vaapi() {
  local codec="$1" out="$2"
  ffmpeg -hide_banner -loglevel error -y -vaapi_device "$device" "${common_in[@]}" \
    -vf "$va_filter" -c:v "$codec" "$out"
}

decode_vaapi() {
  local input="$1"
  ffmpeg -hide_banner -loglevel error -hwaccel vaapi -hwaccel_device "$device" \
    -hwaccel_output_format vaapi -i "$input" -map 0:v:0 -f null -
}

encode_vaapi h264_vaapi "$tmp/h264.mkv"
encode_vaapi hevc_vaapi "$tmp/hevc.mkv"
encode_vaapi av1_vaapi "$tmp/av1.mkv"
decode_vaapi "$tmp/h264.mkv"
decode_vaapi "$tmp/hevc.mkv"
decode_vaapi "$tmp/av1.mkv"

if ffmpeg -hide_banner -encoders 2>/dev/null | grep -Eq '[[:space:]]libvpx-vp9([[:space:]]|$)'; then
  ffmpeg -hide_banner -loglevel error -y "${common_in[@]}" -c:v libvpx-vp9 -deadline realtime -cpu-used 8 "$tmp/vp9.webm"
elif ffmpeg -hide_banner -encoders 2>/dev/null | grep -Eq '[[:space:]]vp9_vaapi([[:space:]]|$)'; then
  encode_vaapi vp9_vaapi "$tmp/vp9.webm"
else
  echo 'No VP9 encoder available to create the functional decode fixture' >&2
  exit 1
fi
decode_vaapi "$tmp/vp9.webm"

printf 'device=%s\n' "$device"
printf 'decode=h264,hevc,vp9,av1\n'
printf 'encode=h264,hevc,av1\n'
printf 'verdict=PASS\n'

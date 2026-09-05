#!/usr/bin/env bash
set -Eeuo pipefail

state_root="${XDG_STATE_HOME:-$HOME/.local/state}/fedora-gnome-custom"
profile="$state_root/display-profile.env"
[[ -r "$profile" ]] || { echo "Certified display profile missing: $profile" >&2; exit 1; }

profile_value() {
  local key="$1"
  awk -F= -v wanted="$key" '$1==wanted {sub(/^[^=]*=/, ""); print; exit}' "$profile"
}

expected_edid="$(profile_value edid_sha256)"
[[ "$expected_edid" =~ ^[0-9a-f]{64}$ ]] || { echo 'Certified EDID hash missing or invalid.' >&2; exit 1; }
[[ "${XDG_SESSION_TYPE:-}" == wayland ]] || { echo 'Display repair requires the GNOME Wayland session.' >&2; exit 1; }
command -v gdctl >/dev/null || { echo 'gdctl is unavailable (Mutter tooling missing).' >&2; exit 1; }

find_b580_bdf() {
  local dev vendor device
  for dev in /sys/bus/pci/devices/*; do
    [[ -r "$dev/vendor" && -r "$dev/device" ]] || continue
    vendor="$(tr '[:upper:]' '[:lower:]' < "$dev/vendor")"
    device="$(tr '[:upper:]' '[:lower:]' < "$dev/device")"
    if [[ "$vendor" == 0x8086 && "$device" == 0xe20b ]]; then
      basename "$dev"; return 0
    fi
  done
  return 1
}

bdf="$(find_b580_bdf)" || { echo 'Intel Arc B580 8086:e20b not found.' >&2; exit 1; }
card=''
for candidate in "/sys/bus/pci/devices/$bdf"/drm/card[0-9]*; do
  [[ -e "$candidate" ]] || continue
  card="$(basename "$candidate")"; break
done
[[ -n "$card" ]] || { echo "No DRM card found for Arc B580 at $bdf." >&2; exit 1; }

matches=()
for path in /sys/class/drm/"$card"-*; do
  [[ -d "$path" && -r "$path/status" && -s "$path/edid" ]] || continue
  [[ "$(<"$path/status")" == connected ]] || continue
  hash="$(sha256sum "$path/edid" | awk '{print $1}')"
  [[ "$hash" == "$expected_edid" ]] || continue
  matches+=("$path")
done
(( ${#matches[@]} == 1 )) || { echo "Expected exactly one connected B580 connector matching certified EDID; found ${#matches[@]}." >&2; exit 1; }
connector_path="${matches[0]}"
connector="$(basename "$connector_path" | sed -E 's/^card[0-9]+-//')"

width="${DISPLAY_TARGET_WIDTH:-2560}"
height="${DISPLAY_TARGET_HEIGHT:-1440}"
refresh="${DISPLAY_TARGET_REFRESH_HZ:-240}"
mode="${width}x${height}@${refresh}"

verify_mode() {
  gdctl set --verify --logical-monitor --primary \
    --scale "${DISPLAY_TARGET_SCALE:-1.0}" \
    --monitor "$connector" --mode "$1" \
    --color-mode "${DISPLAY_TARGET_COLOR_MODE:-default}" \
    --rgb-range "${DISPLAY_TARGET_RGB_RANGE:-full}" >/dev/null 2>&1
}

if ! verify_mode "$mode"; then
  modes_report="$(gdctl show --modes 2>/dev/null || true)"
  mode="$(awk -v monitor="$connector" -v res="${width}x${height}@" -v target="$refresh" '
    $0 ~ ("Monitor " monitor "([ :]|$)") {inside=1; next}
    inside && $0 ~ /^[[:space:]]*Monitor [^ ]+/ {exit}
    inside {
      line=$0
      while (match(line, /[0-9]+x[0-9]+@[0-9.]+/)) {
        m=substr(line,RSTART,RLENGTH); line=substr(line,RSTART+RLENGTH)
        if (index(m,res)==1) {
          split(m,a,"@"); d=a[2]-target; if(d<0)d=-d
          if(best=="" || d<bestd) {best=m; bestd=d}
        }
      }
    }
    END {print best}
  ' <<<"$modes_report")"
fi
[[ -n "$mode" ]] || { echo "No ${width}x${height} mode advertised by certified connector $connector." >&2; exit 1; }
verify_mode "$mode" || { echo "Mode $mode cannot be verified on certified connector $connector." >&2; exit 1; }

gdctl set --persistent --logical-monitor --primary \
  --scale "${DISPLAY_TARGET_SCALE:-1.0}" \
  --monitor "$connector" --mode "$mode" \
  --color-mode "${DISPLAY_TARGET_COLOR_MODE:-default}" \
  --rgb-range "${DISPLAY_TARGET_RGB_RANGE:-full}"

mkdir -p "$state_root"
tmp="$(mktemp "$state_root/.display-repair.XXXXXX")"
{
  printf 'utc=%s\n' "$(date -u +%FT%TZ)"
  printf 'bdf=%s\n' "$bdf"
  printf 'card=%s\n' "$card"
  printf 'connector=%s\n' "$connector"
  printf 'edid_sha256=%s\n' "$expected_edid"
  printf 'mode=%s\n' "$mode"
  gdctl show --verbose 2>&1 || true
} > "$tmp"
chmod 0600 "$tmp"
mv -f "$tmp" "$state_root/display-repair-last.txt"

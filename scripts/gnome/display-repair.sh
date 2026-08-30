#!/usr/bin/env bash
set -Eeuo pipefail

connected_connector() {
  local f
  for f in /sys/class/drm/card*-*/status; do
    [[ -r "$f" ]] || continue
    [[ "$(<"$f")" == connected ]] || continue
    basename "${f%/status}" | sed -E 's/^card[0-9]+-//'
    return 0
  done
  return 1
}

connector="${DISPLAY_CONNECTOR_OVERRIDE:-$(connected_connector || true)}"
[[ -n "$connector" ]] || { echo 'No connected DRM connector found.' >&2; exit 1; }
[[ "${XDG_SESSION_TYPE:-}" == wayland ]] || { echo 'Display repair requires the GNOME Wayland session.' >&2; exit 1; }
command -v gdctl >/dev/null || { echo 'gdctl is unavailable (Mutter tooling missing).' >&2; exit 1; }
width="${DISPLAY_TARGET_WIDTH:-2560}"; height="${DISPLAY_TARGET_HEIGHT:-1440}"; refresh="${DISPLAY_TARGET_REFRESH_HZ:-240}"
mode="${width}x${height}@${refresh}"
# Verify first; if the display reports a fractional refresh (e.g. 239.96), discover that advertised mode.
if ! gdctl set --verify --logical-monitor --primary --scale "${DISPLAY_TARGET_SCALE:-1.0}" --monitor "$connector" --mode "$mode" --color-mode "${DISPLAY_TARGET_COLOR_MODE:-default}" --rgb-range "${DISPLAY_TARGET_RGB_RANGE:-full}" >/dev/null 2>&1; then
  mode="$(gdctl show --modes 2>/dev/null | grep -Eo "${width}x${height}@[0-9.]+" | awk -F@ -v target="$refresh" 'BEGIN{best="";d=999} {x=$2-target;if(x<0)x=-x;if(x<d){d=x;best=$0}} END{print best}')"
fi
[[ -n "$mode" ]] || { echo "No ${width}x${height} mode advertised by $connector" >&2; exit 1; }
gdctl set --persistent --logical-monitor --primary --scale "${DISPLAY_TARGET_SCALE:-1.0}" --monitor "$connector" --mode "$mode" --color-mode "${DISPLAY_TARGET_COLOR_MODE:-default}" --rgb-range "${DISPLAY_TARGET_RGB_RANGE:-full}"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}/fedora-gnome-custom"
mkdir -p "$state_root"
{
  printf 'utc=%s\nconnector=%s\nmode=%s\n' "$(date -u +%FT%TZ)" "$connector" "$mode"
  gdctl show --verbose 2>&1 || true
} > "$state_root/display-repair-last.txt"

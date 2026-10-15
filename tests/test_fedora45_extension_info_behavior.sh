#!/usr/bin/env bash
# Exercise the exact production CI guest function with simulated GNOME Shell
# D-Bus outages. This test never needs a VM or a running desktop.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Extract the actual function (rather than testing a duplicated implementation).
eval "$(sed -n '/^check_extensions() {/,/^}/p' "$ROOT/.github/scripts/fedora-gnome-guest.sh")"
declare -f check_extensions >/dev/null
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
STATE_FILE="$TEMP/count"
LOG="$TEMP/output"
export LAB_EXTENSION_MODE=curated LAB_RELEASE=44
export DASH_TO_DOCK_UUID='dash@test' APPINDICATOR_UUID='indicator@test'
export DING_UUID='ding@test' SHOW_DESKTOP_PLUS_UUID='desktop@test'
export RESOURCE_MONITOR_UUID='vitals@test' TILING_ASSISTANT_UUID='tiling@test'

check_extension_settings() { :; }
sleep() { :; } # Remove 2-second waits in the isolated negative fixture.

as_user() {
  [[ "${1:-}" == timeout && "${2:-}" == --signal=TERM &&
     "${3:-}" == --kill-after=5s && "${4:-}" == 20s &&
     "${5:-}" == gnome-extensions && "${6:-}" == info ]] || return 90
  local count=0 uuid="${7:-}"
  [[ -f "$STATE_FILE" ]] && count="$(cat "$STATE_FILE")"
  count=$((count + 1))
  printf '%s\n' "$count" > "$STATE_FILE"
  if [[ "$uuid" == "$DING_UUID" ]]; then
    case "$SCENARIO" in
      transient) if (( count == 3 )); then echo 'Failed to connect to GNOME Shell' >&2; return 2; fi ;;
      persistent) echo 'Failed to connect to GNOME Shell' >&2; return 2 ;;
      error) printf 'Enabled: Yes\nState: ERROR\n'; return 0 ;;
      inactive) printf 'Enabled: Yes\nState: INACTIVE\n'; return 0 ;;
      disabled) printf 'Enabled: No\nState: ACTIVE\n'; return 0 ;;
    esac
  fi
  printf 'Enabled: Yes\nState: ACTIVE\n'
}

SCENARIO=transient
printf '0\n' > "$STATE_FILE"
check_extensions > "$LOG" 2>&1
grep -Fq 'info query failed (1/60, exit=2)' "$LOG"
[[ "$(cat "$STATE_FILE")" == 7 ]]

for SCENARIO in persistent error inactive disabled; do
  printf '0\n' > "$STATE_FILE"
  if check_extensions > "$LOG" 2>&1; then
    echo "FAIL: GNOME $SCENARIO was wrongly accepted" >&2
    exit 1
  fi
  grep -Fq 'GNOME extension ding@test not confirmed enabled and ACTIVE' "$LOG"
  case "$SCENARIO" in
    persistent)
      grep -Fq 'info query failed (60/60, exit=2)' "$LOG"
      [[ "$(cat "$STATE_FILE")" == 62 ]]
      ;;
    error)
      grep -Fq 'GNOME extension ding@test entered ERROR state' "$LOG"
      [[ "$(cat "$STATE_FILE")" == 3 ]]
      ;;
    inactive|disabled) [[ "$(cat "$STATE_FILE")" == 62 ]] ;;
  esac
done
printf '%s\n' 'GNOME 51 extension info restart/DBus failure guard: PASS'

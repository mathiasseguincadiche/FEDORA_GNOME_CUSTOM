#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
execute=false; minutes=30
while (($#)); do case "$1" in --execute) execute=true; shift ;; --minutes) minutes="${2:?missing minutes}"; shift 2 ;; -h|--help) echo 'Usage: stability-stress.sh --execute [--minutes N]'; exit 0 ;; *) echo "Unknown argument: $1" >&2; exit 2 ;; esac; done
[[ "$minutes" =~ ^[0-9]+$ && "$minutes" -ge 5 ]] || { echo 'Minimum stress duration is 5 minutes.' >&2; exit 2; }
$execute || { echo 'Refusing stress test without --execute.' >&2; exit 2; }
command -v stress-ng >/dev/null 2>&1 || { echo 'stress-ng is required.' >&2; exit 20; }
command -v dmidecode >/dev/null 2>&1 || { echo 'dmidecode is required to certify configured DDR5 speed.' >&2; exit 20; }
out="$STATE_ROOT/stability-stress/$(date -u +%Y%m%dT%H%M%SZ)"; mkdir -p "$out"
configured="$(sudo dmidecode --type 17 2>/dev/null | awk -F: '/Configured Memory Speed:/ {gsub(/^[ \t]+|[ \t]+$/,"",$2); if ($2 ~ /^[0-9]+ MT\/s$/) print $2}' | sort -u | paste -sd, -)" || true
expected_speed="${EXPECTED_RAM_MT_S} MT/s"
if [[ "$configured" != "$expected_speed" ]]; then
  printf 'Configured DDR5 speed is %s; expected exactly %s for the certified %s profile.\n' "${configured:-unavailable}" "$expected_speed" "${EXPECTED_MEMORY_PROFILE:-memory profile}" >&2
  exit 30
fi
printf 'Pre-stress DDR5 profile: %s (%s)\n' "$configured" "${EXPECTED_MEMORY_PROFILE:-profile}"
start="$(date --iso-8601=seconds)"
stress-ng --cpu 0 --cpu-method all --vm 2 --vm-bytes 50% --vm-keep --cache 2 --verify --metrics-brief --timeout "${minutes}m" 2>&1 | tee "$out/stress-ng.log"
journalctl -k --since "$start" --no-pager 2>/dev/null > "$out/kernel.log" || true
if grep -Eqi 'MCE|hardware error|EDAC.*error|GPU HANG|wedged|AER:.*fatal|watchdog.*lockup' "$out/kernel.log"; then echo 'Stability stress: FAIL'; exit 1; fi
configured_after="$(sudo dmidecode --type 17 2>/dev/null | awk -F: '/Configured Memory Speed:/ {gsub(/^[ \t]+|[ \t]+$/,"",$2); if ($2 ~ /^[0-9]+ MT\/s$/) print $2}' | sort -u | paste -sd, -)" || true
[[ "$configured_after" == "$expected_speed" ]] || { echo 'Configured DDR5 speed changed or became unreadable after stress.' >&2; exit 31; }
printf 'result=PASS\nminutes=%s\nconfigured_memory_speed=%s\nmemory_profile=%s\nutc=%s\n' "$minutes" "$configured_after" "${EXPECTED_MEMORY_PROFILE:-unknown}" "$(date -u +%FT%TZ)" > "$out/result.env"
ln -sfn "$out" "$STATE_ROOT/stability-stress/latest"
echo "Stability stress: PASS — DDR5 ${EXPECTED_RAM_MT_S} MT/s certified for this run"

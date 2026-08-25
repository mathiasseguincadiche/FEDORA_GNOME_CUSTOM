#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
execute=false; minutes=30
while (($#)); do case "$1" in --execute) execute=true; shift ;; --minutes) minutes="${2:?missing minutes}"; shift 2 ;; -h|--help) echo 'Usage: stability-stress.sh --execute [--minutes N]'; exit 0 ;; *) echo "Unknown argument: $1" >&2; exit 2 ;; esac; done
[[ "$minutes" =~ ^[0-9]+$ && "$minutes" -ge 5 ]] || { echo 'Minimum stress duration is 5 minutes.' >&2; exit 2; }
$execute || { echo 'Refusing stress test without --execute.' >&2; exit 2; }
command -v stress-ng >/dev/null 2>&1 || { echo 'stress-ng is required.' >&2; exit 20; }
out="$STATE_ROOT/stability-stress/$(date -u +%Y%m%dT%H%M%SZ)"; mkdir -p "$out"
start="$(date --iso-8601=seconds)"
stress-ng --cpu 0 --cpu-method all --vm 2 --vm-bytes 50% --vm-keep --cache 2 --verify --metrics-brief --timeout "${minutes}m" 2>&1 | tee "$out/stress-ng.log"
journalctl -k --since "$start" --no-pager 2>/dev/null > "$out/kernel.log" || true
if grep -Eqi 'MCE|hardware error|EDAC.*error|GPU HANG|wedged|AER:.*fatal|watchdog.*lockup' "$out/kernel.log"; then echo 'Stability stress: FAIL'; exit 1; fi
configured="$(sudo dmidecode --type 17 2>/dev/null | awk -F: '/Configured Memory Speed:/ {gsub(/^[ \t]+/,"",$2); print $2}' | sort -u | paste -sd, -)" || true
printf 'result=PASS\nminutes=%s\nconfigured_memory_speed=%s\nutc=%s\n' "$minutes" "$configured" "$(date -u +%FT%TZ)" > "$out/result.env"
ln -sfn "$out" "$STATE_ROOT/stability-stress/latest"
echo 'Stability stress: PASS'

#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
execute=false; cycles="${POWER_SUSPEND_CERTIFICATION_CYCLES:-10}"
while (($#)); do case "$1" in --execute) execute=true; shift ;; --cycles) cycles="${2:?missing cycles}"; shift 2 ;; -h|--help) echo 'Usage: suspend-certify.sh --execute [--cycles N]'; exit 0 ;; *) echo "Unknown argument: $1" >&2; exit 2 ;; esac; done
[[ "$cycles" =~ ^[0-9]+$ && "$cycles" -ge 1 ]] || { echo 'Invalid cycle count.' >&2; exit 2; }
$execute || { echo 'Refusing to suspend without --execute.' >&2; exit 2; }
[[ -t 0 ]] || { echo 'Interactive terminal required.' >&2; exit 2; }
read -r -p "Execute $cycles real suspend/resume cycles? [yes/NO] " answer
[[ "$answer" == yes ]] || { echo 'Cancelled.'; exit 0; }
out="$STATE_ROOT/suspend-certification/$(date -u +%Y%m%dT%H%M%SZ)"; mkdir -p "$out"
for ((i=1; i<=cycles; i++)); do
  printf 'cycle=%d start=%s\n' "$i" "$(date -u +%FT%TZ)" | tee "$out/cycle-$i.log"
  sudo systemctl suspend
  sleep "${POWER_SUSPEND_SETTLE_SECONDS:-15}"
  printf 'resume=%s\n' "$(date -u +%FT%TZ)" | tee -a "$out/cycle-$i.log"
  "$REPO_ROOT/diagnostics/kernel-doctor" >> "$out/cycle-$i.log" 2>&1 || true
  "$REPO_ROOT/diagnostics/power-doctor" >> "$out/cycle-$i.log" 2>&1 || true
  journalctl -k -b --since '-5 min' --no-pager 2>/dev/null | grep -Ei 'PM:|suspend|resume|xe|drm|AER:|PCIe Bus Error|nvme|watchdog|hardware error' >> "$out/cycle-$i.log" || true
done
if grep -REqi 'GPU HANG|wedged|AER:.*fatal|hardware error|watchdog.*lockup' "$out"; then echo 'Suspend certification: FAIL'; exit 1; fi
printf 'cycles=%s\nresult=PASS\nutc=%s\n' "$cycles" "$(date -u +%FT%TZ)" > "$out/result.env"
ln -sfn "$out" "$STATE_ROOT/suspend-certification/latest"
echo "Suspend certification: PASS ($cycles cycles)"

#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
report="$REPORT_ROOT/$RUN_ID-workstation-certification.txt"; : > "$report"
pass=0; warn=0; fail=0
run_check() { local name="$1" cmd="$2"; if "$REPO_ROOT/diagnostics/$cmd" >> "$report" 2>&1; then printf 'PASS %s\n' "$name" | tee -a "$report"; ((pass+=1)); else printf 'FAIL %s\n' "$name" | tee -a "$report"; ((fail+=1)); fi; }
run_check kernel kernel-doctor
run_check topology hardware-topology-doctor
run_check power power-doctor
if [[ "${XDG_SESSION_TYPE:-}" == wayland ]]; then run_check display display-pipeline-doctor; else printf 'WARN display: run inside GNOME Wayland\n' | tee -a "$report"; ((warn+=1)); fi
stress_result="$STATE_ROOT/stability-stress/latest/result.env"; if [[ -r "$stress_result" ]] && grep -Fqx 'result=PASS' "$stress_result"; then echo 'PASS stability-stress' | tee -a "$report"; ((pass+=1)); else echo 'WARN stability-stress evidence missing' | tee -a "$report"; ((warn+=1)); fi
suspend_result="$STATE_ROOT/suspend-certification/latest/result.env"; if [[ -r "$suspend_result" ]] && grep -Fqx 'result=PASS' "$suspend_result" && awk -F= -v min="${POWER_SUSPEND_CERTIFICATION_CYCLES:-10}" '$1=="cycles" && $2>=min {ok=1} END {exit !ok}' "$suspend_result"; then echo 'PASS suspend-resume' | tee -a "$report"; ((pass+=1)); else echo 'WARN suspend-resume certification incomplete' | tee -a "$report"; ((warn+=1)); fi
printf 'PASS=%d WARN=%d FAIL=%d\n' "$pass" "$warn" "$fail" | tee -a "$report"
(( fail == 0 ))

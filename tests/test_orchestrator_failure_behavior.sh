#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -a "$ROOT/lib" "$ROOT/config" "$tmp/"
mkdir -p "$tmp/scripts" "$tmp/logs" "$tmp/reports"
cp -a "$ROOT/scripts/config" "$tmp/scripts/"
export REPO_ROOT="$tmp" LOG_DIR="$tmp/logs" MODULE_LOG="$tmp/logs/modules.log"
export MAIN_LOG="$tmp/logs/main.log" REPORT_ROOT="$tmp/reports" RUN_ID=failure
export RUNTIME_ENVIRONMENT=ci DRY_RUN=true
source "$ROOT/lib/orchestrator.sh"
declare -a CATALOG_IDS=(fixture.module next.module)
declare -A CATALOG_PATH=([fixture.module]=fixture.sh [next.module]=next.sh)
declare -A CATALOG_SCOPE=([fixture.module]=TEST [next.module]=TEST)
cat > "$tmp/next.sh" <<'SH'
next_module_precheck() { :; }
next_module_plan() { :; }
next_module_apply() { :; }
next_module_postcheck() { :; }
SH
for broken_phase in source precheck plan apply postcheck; do
  cat > "$tmp/fixture.sh" <<'SH'
fixture_module_precheck() { :; }
fixture_module_plan() { :; }
fixture_module_apply() { :; }
fixture_module_postcheck() { :; }
SH
  if [[ "$broken_phase" == source ]]; then
    printf '(exit 37)\nprintf BAD > "%s/sentinel"\n' "$tmp" >> "$tmp/fixture.sh"
  else
    printf 'fixture_module_%s() { (exit 37); printf BAD > "%s/sentinel"; }\n' "$broken_phase" "$tmp" >> "$tmp/fixture.sh"
  fi
  rc=0
  # Intentionally conditional: this used to suppress errexit inside modules.
  orchestrator_run_all || rc=$?
  [[ "$rc" == 37 && ! -e "$tmp/sentinel" ]]
  [[ ${#ORCH_RESULTS[@]} == 1 && "${ORCH_RESULTS[0]}" == "KO|fixture.module|$broken_phase|37|"* ]]
done
# Early exit 0 must not masquerade as completion.
printf 'exit 0\n' > "$tmp/fixture.sh"
rc=0
orchestrator_run_all || rc=$?
[[ "$rc" == 60 && "${ORCH_RESULTS[0]}" == *'premature successful exit' ]]
cat > "$tmp/fixture.sh" <<'SH'
fixture_module_precheck() { :; }
fixture_module_plan() { :; }
fixture_module_apply() { return 37; }
fixture_module_postcheck() { :; }
SH
ORCH_COLLECT_ALL=true
rc=0
orchestrator_run_all || rc=$?
[[ "$rc" == 37 && ${#ORCH_RESULTS[@]} == 2 ]]
[[ "${ORCH_RESULTS[1]}" == 'OK|next.module|complete|0|'* ]]
DRY_RUN=false
rc=0
orchestrator_run_all || rc=$?
[[ "$rc" == 50 ]]
echo 'orchestrator failure behavior: PASS'

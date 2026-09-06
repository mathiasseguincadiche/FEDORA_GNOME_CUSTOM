#!/usr/bin/env bash
# shellcheck disable=SC2317
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Dynamic proof that run_mutating never executes its command in dry-run.
sentinel="$tmp/sentinel.sh"
cat > "$sentinel" <<SH
#!/usr/bin/env bash
printf 'called\n' >> '$tmp/mutations.log'
SH
chmod +x "$sentinel"
(
  is_true() { [[ "${1,,}" == true ]]; }
  log_info() { :; }
  source "$ROOT/lib/mutations.sh"
  DRY_RUN=true
  run_mutating TEST "$sentinel"
  [[ ! -e "$tmp/mutations.log" ]]
  DRY_RUN=false
  run_mutating TEST "$sentinel"
  [[ "$(wc -l < "$tmp/mutations.log")" -eq 1 ]]
)

# Dynamic proof that module-local helpers cannot leak into the next convergence module.
cat > "$tmp/a.sh" <<'SH'
a_module_precheck() { :; }
a_module_plan() { :; }
a_module_apply() { :; }
a_module_postcheck() { :; }
leaked_helper_from_a() { :; }
SH
cat > "$tmp/b.sh" <<'SH'
b_module_precheck() {
  if declare -F leaked_helper_from_a >/dev/null; then
    echo 'module A helper leaked into module B' >&2
    return 77
  fi
}
b_module_plan() { :; }
b_module_apply() { :; }
b_module_postcheck() { :; }
SH
(
  REPO_ROOT="$tmp"
  LOG_DIR="$tmp/logs"
  MODULE_LOG="$tmp/modules.log"
  REPORT_ROOT="$tmp/reports"
  RUN_ID='isolation-test'
  RUNTIME_ENVIRONMENT='ci'
  DRY_RUN=true
  EXIT_CONFIG_FAILED=12
  mkdir -p "$LOG_DIR" "$REPORT_ROOT"
  declare -a CATALOG_IDS=(a.module b.module)
  declare -A CATALOG_PATH=( [a.module]='a.sh' [b.module]='b.sh' )
  declare -A CATALOG_SCOPE=( [a.module]='TEST' [b.module]='TEST' )
  ui_check() { :; }
  is_true() { [[ "${1,,}" == true ]]; }
  repo_commit() { printf 'test-commit\n'; }
  source "$ROOT/lib/orchestrator.sh"
  orchestrator_run_all
  [[ "${ORCH_RESULTS[*]}" == *'OK|a.module|complete|0|'* ]]
  [[ "${ORCH_RESULTS[*]}" == *'OK|b.module|complete|0|'* ]]
  report="$(orchestrator_report)"
  [[ -s "$report" ]]
  [[ -s "$REPORT_ROOT/run-$RUN_ID.json" ]]
  python3 - "$REPORT_ROOT/run-$RUN_ID.json" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as f:
    data=json.load(f)
assert data['overall'] == 'PASS'
assert [m['module'] for m in data['modules']] == ['a.module','b.module']
assert all(isinstance(m['duration_ms'], int) and m['duration_ms'] >= 0 for m in data['modules'])
PY
)

echo 'mutation wrapper and module isolation behavior: PASS'

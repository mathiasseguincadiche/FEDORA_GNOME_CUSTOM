#!/usr/bin/env bash
# REPO_ROOT is intentionally injected by the repository entrypoints before this library is sourced.
# shellcheck disable=SC2153

ORCHESTRATOR_RUNNER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/engine/run-module.sh"
declare -ag ORCH_RESULTS=()

module_prefix() { printf '%s' "${1//./_}"; }

orchestrator_now_ms() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import time; print(time.monotonic_ns() // 1_000_000)'
  else
    printf '%s000\n' "$(date +%s)"
  fi
}

orchestrator_run_module() {
  local id="$1"
  local path="$REPO_ROOT/${CATALOG_PATH[$id]}"
  local prefix rc=0 state='KO' phase='source' detail='' start_ms end_ms duration_ms
  local status_root status_file
  prefix="$(module_prefix "$id")"
  status_root="${LOG_DIR:-${TMPDIR:-/tmp}}"
  mkdir -p "$status_root"
  status_file="$(mktemp "$status_root/.orchestrator-${id//[^A-Za-z0-9_.-]/_}.XXXXXX")"
  start_ms="$(orchestrator_now_ms)"

  # A separate Bash process is essential: calling a function/subshell in an
  # if/|| condition disables errexit throughout its body, even with set -e.
  if REPO_ROOT="$REPO_ROOT" DRY_RUN="${DRY_RUN:-true}" \
      RUNTIME_ENVIRONMENT="${RUNTIME_ENVIRONMENT:-unknown}" \
      MODULE_LOG="$MODULE_LOG" bash "$ORCHESTRATOR_RUNNER" \
      "$path" "$prefix" "$status_file" "$id" "${CATALOG_SCOPE[$id]}"; then
    rc=0
  else
    rc=$?
  fi

  end_ms="$(orchestrator_now_ms)"
  duration_ms=$((end_ms - start_ms))
  if [[ -s "$status_file" ]]; then
    IFS='|' read -r state phase _ detail < "$status_file"
  else
    state='KO'; phase='internal'; detail="orchestrator subprocess rc=$rc"
  fi
  # Explicit exit(0) during a phase must not become a successful installation.
  if [[ "$state" != OK && "$rc" == 0 ]]; then rc="${EXIT_POSTCHECK_FAILED:-40}"; fi
  rm -f "$status_file"

  ORCH_RESULTS+=("$state|$id|$phase|$rc|$duration_ms|$detail")
  return "$rc"
}

orchestrator_run_all() {
  local id rc=0 module_rc
  [[ "${ORCH_COLLECT_ALL:-false}" != true || "${DRY_RUN:-true}" == true ]] || return "${EXIT_SECURITY_BLOCK:-50}"
  ORCH_RESULTS=()
  for id in "${CATALOG_IDS[@]}"; do
    if orchestrator_run_module "$id"; then
      :
    else
      module_rc=$?
      (( rc != 0 )) || rc=$module_rc
      [[ "${ORCH_COLLECT_ALL:-false}" == true ]] || return "$rc"
    fi
  done
  return "$rc"
}

orchestrator_report() {
  local report="$REPORT_ROOT/run-$RUN_ID.txt" json="$REPORT_ROOT/run-$RUN_ID.json" mode='apply'
  local report_tmp json_tmp results_tmp config_hash='unavailable' plan_hash='unavailable' overall='PASS'
  is_true "${DRY_RUN:-true}" && mode='dry-run'
  declare -F effective_config_sha256 >/dev/null && config_hash="$(effective_config_sha256)"
  declare -F module_plan_sha256 >/dev/null && plan_hash="$(module_plan_sha256)"
  local result
  for result in "${ORCH_RESULTS[@]}"; do
    [[ "$result" != KO\|* ]] || overall='FAIL'
  done
  (( ${#ORCH_RESULTS[@]} == ${#CATALOG_IDS[@]} )) || overall='FAIL'

  mkdir -p "$REPORT_ROOT"
  report_tmp="$(mktemp "$REPORT_ROOT/.run-$RUN_ID.txt.XXXXXX")"
  {
    printf 'FEDORA_GNOME_CUSTOM REPORT\n'
    printf 'run_id=%s\nmode=%s\nruntime=%s\ncommit=%s\neffective_config_sha256=%s\nmodule_plan_sha256=%s\noverall=%s\n\n' \
      "$RUN_ID" "$mode" "${RUNTIME_ENVIRONMENT:-unknown}" "$(repo_commit)" "$config_hash" "$plan_hash" "$overall"
    printf '%-5s | %-28s | %-10s | %-4s | %-11s | %s\n' STATE MODULE PHASE RC DURATION_MS DETAIL
    printf '%s\n' '------+------------------------------+------------+------+-------------+-----------------------------'
    printf '%s\n' "${ORCH_RESULTS[@]}" | awk -F'|' '{printf "%-5s | %-28s | %-10s | %-4s | %-11s | %s\n",$1,$2,$3,$4,$5,$6}'
  } > "$report_tmp"
  chmod 0600 "$report_tmp"
  mv -f "$report_tmp" "$report"

  results_tmp="$(mktemp "$REPORT_ROOT/.run-$RUN_ID.results.XXXXXX")"
  printf '%s\n' "${ORCH_RESULTS[@]}" > "$results_tmp"
  json_tmp="$(mktemp "$REPORT_ROOT/.run-$RUN_ID.json.XXXXXX")"
  python3 - "$results_tmp" "$RUN_ID" "$mode" "${RUNTIME_ENVIRONMENT:-unknown}" "$(repo_commit)" "$config_hash" "$plan_hash" "$overall" <<'PY' > "$json_tmp"
import json
import sys

rows_path, run_id, mode, runtime, commit, config_hash, plan_hash, overall = sys.argv[1:]
modules = []
with open(rows_path, encoding="utf-8") as handle:
    for raw in handle:
        raw = raw.rstrip("\n")
        if not raw:
            continue
        state, module, phase, rc, duration_ms, detail = raw.split("|", 5)
        modules.append({
            "state": state,
            "module": module,
            "phase": phase,
            "rc": int(rc),
            "duration_ms": int(duration_ms),
            "detail": detail,
        })
print(json.dumps({
    "schema": 1,
    "run_id": run_id,
    "mode": mode,
    "runtime": runtime,
    "commit": commit,
    "effective_config_sha256": config_hash,
    "module_plan_sha256": plan_hash,
    "overall": overall,
    "modules": modules,
}, indent=2, sort_keys=True))
PY
  chmod 0600 "$json_tmp"
  mv -f "$json_tmp" "$json"
  rm -f "$results_tmp"
  printf '%s\n' "$report"
}

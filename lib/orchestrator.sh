#!/usr/bin/env bash
# REPO_ROOT is intentionally injected by the repository entrypoints before this library is sourced.
# shellcheck disable=SC2153

declare -ag ORCH_RESULTS=()

module_prefix() { printf '%s' "${1//./_}"; }

orchestrator_run_module() {
  local id="$1"
  local path="$REPO_ROOT/${CATALOG_PATH[$id]}"
  local prefix rc=0
  prefix="$(module_prefix "$id")"
  # shellcheck disable=SC1090
  source "$path"
  ui_check INFO "$id" "${CATALOG_SCOPE[$id]}"

  if declare -F "${prefix}_precheck" >/dev/null; then
    "${prefix}_precheck" || { rc=$?; ORCH_RESULTS+=("KO|$id|precheck rc=$rc"); return "$rc"; }
  fi
  if declare -F "${prefix}_plan" >/dev/null; then
    "${prefix}_plan" >> "$MODULE_LOG" 2>&1 || { rc=$?; ORCH_RESULTS+=("KO|$id|plan rc=$rc"); return "$rc"; }
  fi
  if declare -F "${prefix}_apply" >/dev/null; then
    "${prefix}_apply" >> "$MODULE_LOG" 2>&1 || { rc=$?; ORCH_RESULTS+=("KO|$id|apply rc=$rc"); return "$rc"; }
  fi
  if declare -F "${prefix}_postcheck" >/dev/null; then
    "${prefix}_postcheck" >> "$MODULE_LOG" 2>&1 || { rc=$?; ORCH_RESULTS+=("KO|$id|postcheck rc=$rc"); return "$rc"; }
  fi
  ORCH_RESULTS+=("OK|$id|complete")
}

orchestrator_run_all() {
  local id
  ORCH_RESULTS=()
  for id in "${CATALOG_IDS[@]}"; do
    orchestrator_run_module "$id" || return "$?"
  done
}

orchestrator_report() {
  local report="$REPORT_ROOT/$RUN_ID-orchestrator.txt" line
  printf 'run_id=%s\ncommit=%s\ndry_run=%s\n' "$RUN_ID" "$(repo_commit)" "${DRY_RUN:-true}" > "$report"
  for line in "${ORCH_RESULTS[@]}"; do printf '%s\n' "$line" >> "$report"; done
  printf '%s\n' "$report"
}

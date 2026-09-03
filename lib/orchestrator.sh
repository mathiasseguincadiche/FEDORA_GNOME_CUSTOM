#!/usr/bin/env bash
# REPO_ROOT is intentionally injected by the repository entrypoints before this library is sourced.
# shellcheck disable=SC2153

declare -ag ORCH_RESULTS=()

module_prefix() { printf '%s' "${1//./_}"; }

orchestrator_run_module() {
  local id="$1"
  local path="$REPO_ROOT/${CATALOG_PATH[$id]}"
  local prefix rc=0 phase fn
  prefix="$(module_prefix "$id")"

  if ! source "$path"; then
    rc=$?
    ORCH_RESULTS+=("KO|$id|source rc=$rc")
    return "${rc:-$EXIT_CONFIG_FAILED}"
  fi

  # Every catalog module is a convergence unit. A missing lifecycle function is
  # a contract violation, never an implicit successful no-op.
  for phase in precheck plan apply postcheck; do
    fn="${prefix}_${phase}"
    if ! declare -F "$fn" >/dev/null; then
      ORCH_RESULTS+=("KO|$id|contract missing $fn")
      return "${EXIT_CONFIG_FAILED:-12}"
    fi
  done

  ui_check INFO "$id" "${CATALOG_SCOPE[$id]}"

  "${prefix}_precheck" || { rc=$?; ORCH_RESULTS+=("KO|$id|precheck rc=$rc"); return "$rc"; }
  "${prefix}_plan" >> "$MODULE_LOG" 2>&1 || { rc=$?; ORCH_RESULTS+=("KO|$id|plan rc=$rc"); return "$rc"; }
  "${prefix}_apply" >> "$MODULE_LOG" 2>&1 || { rc=$?; ORCH_RESULTS+=("KO|$id|apply rc=$rc"); return "$rc"; }
  "${prefix}_postcheck" >> "$MODULE_LOG" 2>&1 || { rc=$?; ORCH_RESULTS+=("KO|$id|postcheck rc=$rc"); return "$rc"; }
  ORCH_RESULTS+=("OK|$id|complete")
}

orchestrator_run_all() {
  local id
  ORCH_RESULTS=()
  for id in "${CATALOG_IDS[@]}"; do
    orchestrator_run_module "$id" || return $?
  done
}

orchestrator_report() {
  local report="$REPORT_ROOT/run-$RUN_ID.txt"
  {
    printf 'FEDORA_GNOME_CUSTOM REPORT\n'
    printf 'run_id=%s\nmode=%s\nruntime=%s\ncommit=%s\n\n' "$RUN_ID" "${DRY_RUN:+dry-run}" "${RUNTIME_ENVIRONMENT:-unknown}" "$(repo_commit)"
    printf '%-5s | %-28s | %s\n' STATE MODULE DETAIL
    printf '%s\n' '------+------------------------------+-----------------------------'
    printf '%s\n' "${ORCH_RESULTS[@]}" | awk -F'|' '{printf "%-5s | %-28s | %s\n",$1,$2,$3}'
  } > "$report"
  printf '%s\n' "$report"
}

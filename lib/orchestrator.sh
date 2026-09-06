#!/usr/bin/env bash
# REPO_ROOT is intentionally injected by the repository entrypoints before this library is sourced.
# shellcheck disable=SC2153

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

  if (
    local inner_rc=0 inner_phase fn
    if source "$path"; then
      :
    else
      inner_rc=$?
      printf 'KO|source|%s|source rc=%s\n' "$inner_rc" "$inner_rc" > "$status_file"
      exit "$inner_rc"
    fi

    for inner_phase in precheck plan apply postcheck; do
      fn="${prefix}_${inner_phase}"
      if ! declare -F "$fn" >/dev/null; then
        inner_rc="${EXIT_CONFIG_FAILED:-12}"
        printf 'KO|contract|%s|contract missing %s\n' "$inner_rc" "$fn" > "$status_file"
        exit "$inner_rc"
      fi
    done

    ui_check INFO "$id" "${CATALOG_SCOPE[$id]}"

    if "${prefix}_precheck"; then :; else
      inner_rc=$?
      printf 'KO|precheck|%s|precheck rc=%s\n' "$inner_rc" "$inner_rc" > "$status_file"
      exit "$inner_rc"
    fi
    if "${prefix}_plan" >> "$MODULE_LOG" 2>&1; then :; else
      inner_rc=$?
      printf 'KO|plan|%s|plan rc=%s\n' "$inner_rc" "$inner_rc" > "$status_file"
      exit "$inner_rc"
    fi
    if "${prefix}_apply" >> "$MODULE_LOG" 2>&1; then :; else
      inner_rc=$?
      printf 'KO|apply|%s|apply rc=%s\n' "$inner_rc" "$inner_rc" > "$status_file"
      exit "$inner_rc"
    fi
    if "${prefix}_postcheck" >> "$MODULE_LOG" 2>&1; then :; else
      inner_rc=$?
      printf 'KO|postcheck|%s|postcheck rc=%s\n' "$inner_rc" "$inner_rc" > "$status_file"
      exit "$inner_rc"
    fi

    printf 'OK|complete|0|complete\n' > "$status_file"
  ); then
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
  rm -f "$status_file"

  ORCH_RESULTS+=("$state|$id|$phase|$rc|$duration_ms|$detail")
  return "$rc"
}

orchestrator_run_all() {
  local id
  ORCH_RESULTS=()
  for id in "${CATALOG_IDS[@]}"; do
    orchestrator_run_module "$id" || return $?
  done
}

orchestrator_report() {
  local report="$REPORT_ROOT/run-$RUN_ID.txt" json="$REPORT_ROOT/run-$RUN_ID.json" mode='apply'
  local report_tmp json_tmp results_tmp config_hash='unavailable' plan_hash='unavailable' overall='PASS'
  is_true "${DRY_RUN:-true}" && mode='dry-run'
  declare -F effective_config_sha256 >/dev/null && config_hash="$(effective_config_sha256)"
  declare -F module_plan_sha256 >/dev/null && plan_hash="$(module_plan_sha256)"
  printf '%s\n' "${ORCH_RESULTS[@]}" | grep -q '^KO|' && overall='FAIL'

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

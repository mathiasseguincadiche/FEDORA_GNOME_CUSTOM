#!/usr/bin/env bash
# REPO_ROOT is intentionally injected by the repository entrypoints before this library is sourced.
# shellcheck disable=SC2153

apply_gate_dryrun_proof_path() { printf '%s/dryrun-%s.ok' "$STATE_ROOT" "$(repo_commit)"; }

apply_gate_write_dryrun_proof() {
  local proof
  proof="$(apply_gate_dryrun_proof_path)"
  {
    printf 'verdict=PASS\n'
    printf 'commit=%s\n' "$(repo_commit)"
    printf 'run_id=%s\n' "$RUN_ID"
    printf 'utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'effective_config_sha256=%s\n' "$(effective_config_sha256)"
    printf 'module_plan_sha256=%s\n' "$(module_plan_sha256)"
    printf 'hardware_fingerprint=%s\n' "$(evidence_hardware_fingerprint)"
  } | evidence_atomic_write "$proof" 0600
}

apply_gate_require_runtime() { runtime_is_baremetal; }

apply_gate_require_clean_git() {
  is_true "${REQUIRE_CLEAN_GIT:-true}" || return 0
  [[ -z "$(git -C "$REPO_ROOT" status --porcelain)" ]]
}

apply_gate_require_dryrun() {
  is_true "${REQUIRE_SAME_COMMIT_DRYRUN:-true}" || return 0
  local proof
  proof="$(apply_gate_dryrun_proof_path)"
  [[ -s "$proof" ]] || return 1
  grep -Fxq 'verdict=PASS' "$proof" || return 1
  evidence_require_current_identity "$proof"
}

apply_gate_require_backup() {
  is_true "${REQUIRE_PREAPPLY_BACKUP:-true}" || return 0
  local marker="$STATE_ROOT/preapply-backup.ok" age now ts max
  [[ -s "$marker" ]] || return 1
  evidence_require_current_identity "$marker" || return 1
  ts="$(stat -c %Y "$marker")"; now="$(date +%s)"; max=$(( ${BACKUP_MAX_AGE_HOURS:-24} * 3600 ))
  age=$(( now - ts ))
  (( age >= 0 && age <= max )) || return 1
  backup_runtime_validate_preapply_marker "$marker"
}

apply_gate_require_baseline() {
  is_true "${REQUIRE_HARDWARE_BASELINE_CERTIFIED:-true}" || return 0
  baseline_certification_valid && baseline_automatic_health_check
}

apply_gate_open() {
  apply_gate_require_runtime || {
    ui_error "REAL APPLY is forbidden outside bare-metal; detected runtime=$(runtime_environment)"
    return "$EXIT_SECURITY_BLOCK"
  }
  is_true "${REAL_APPLY_FEATURE_ENABLED:-false}" || { ui_error 'REAL APPLY feature disabled'; return "$EXIT_SECURITY_BLOCK"; }
  is_true "${REAL_MACHINE_APPROVED:-false}" || { ui_error 'REAL_MACHINE_APPROVED=false; use config/local.conf after reviewing the target machine'; return "$EXIT_SECURITY_BLOCK"; }
  [[ -t 0 && -t 1 ]] || { ui_error 'interactive TTY required'; return "$EXIT_SECURITY_BLOCK"; }
  apply_gate_require_clean_git || { ui_error 'Git working tree must be clean'; return "$EXIT_SECURITY_BLOCK"; }
  apply_gate_require_dryrun || { ui_error 'dry-run proof is missing/stale for the current commit, effective configuration, module plan or hardware fingerprint'; return "$EXIT_SECURITY_BLOCK"; }
  apply_gate_require_baseline || { ui_error 'hardware baseline certification missing or invalid for the current hardware/BIOS fingerprint'; return "$EXIT_SECURITY_BLOCK"; }
  apply_gate_require_backup || { ui_error 'pre-APPLY Restic snapshot is missing, stale, no longer readable, or does not match current commit/config/hardware'; return "$EXIT_SECURITY_BLOCK"; }
  local answer
  printf 'Type exactly "%s": ' "$APPLY_CONFIRMATION"
  read -r answer
  [[ "$answer" == "$APPLY_CONFIRMATION" ]] || return "$EXIT_SECURITY_BLOCK"
}

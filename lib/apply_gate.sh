#!/usr/bin/env bash

apply_gate_dryrun_proof_path() { printf '%s/dryrun-%s.ok' "$STATE_ROOT" "$(repo_commit)"; }

apply_gate_write_dryrun_proof() {
  local proof
  proof="$(apply_gate_dryrun_proof_path)"
  printf 'commit=%s\nrun_id=%s\nutc=%s\n' "$(repo_commit)" "$RUN_ID" "$(date -u +%FT%TZ)" > "$proof"
}

apply_gate_require_clean_git() {
  is_true "${REQUIRE_CLEAN_GIT:-true}" || return 0
  [[ -z "$(git -C "$REPO_ROOT" status --porcelain)" ]]
}

apply_gate_require_dryrun() {
  is_true "${REQUIRE_SAME_COMMIT_DRYRUN:-true}" || return 0
  [[ -s "$(apply_gate_dryrun_proof_path)" ]]
}

apply_gate_require_backup() {
  is_true "${REQUIRE_PREAPPLY_BACKUP:-true}" || return 0
  local marker="$STATE_ROOT/preapply-backup.ok"
  [[ -s "$marker" ]] || return 1
  local age now ts max
  ts="$(stat -c %Y "$marker")"; now="$(date +%s)"; max=$(( ${BACKUP_MAX_AGE_HOURS:-24} * 3600 ))
  (( now - ts <= max ))
}

apply_gate_require_baseline() {
  is_true "${REQUIRE_HARDWARE_BASELINE_CERTIFIED:-true}" || return 0
  baseline_certification_valid
}

apply_gate_open() {
  is_true "${REAL_APPLY_FEATURE_ENABLED:-false}" || { ui_error 'REAL APPLY feature disabled'; return "$EXIT_SECURITY_BLOCK"; }
  is_true "${REAL_MACHINE_APPROVED:-false}" || { ui_error 'REAL_MACHINE_APPROVED=false; use config/local.conf after reviewing the target machine'; return "$EXIT_SECURITY_BLOCK"; }
  [[ -t 0 && -t 1 ]] || { ui_error 'interactive TTY required'; return "$EXIT_SECURITY_BLOCK"; }
  apply_gate_require_clean_git || { ui_error 'Git working tree must be clean'; return "$EXIT_SECURITY_BLOCK"; }
  apply_gate_require_dryrun || { ui_error 'same-commit dry-run proof missing'; return "$EXIT_SECURITY_BLOCK"; }
  apply_gate_require_baseline || { ui_error 'hardware baseline certification missing or invalid for the current hardware/BIOS fingerprint'; return "$EXIT_SECURITY_BLOCK"; }
  apply_gate_require_backup || { ui_error 'verified pre-APPLY backup marker missing or stale'; return "$EXIT_SECURITY_BLOCK"; }
  local answer
  printf 'Type exactly "%s": ' "$APPLY_CONFIRMATION"
  read -r answer
  [[ "$answer" == "$APPLY_CONFIRMATION" ]] || return "$EXIT_SECURITY_BLOCK"
}

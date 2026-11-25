#!/usr/bin/env bash
# REPO_ROOT is intentionally injected by the repository entrypoints before this library is sourced.
# shellcheck disable=SC2153

apply_gate_dryrun_proof_path() { printf '%s/dryrun-%s.ok' "$STATE_ROOT" "$(repo_commit)"; }

# An attempted recheck invalidates the old proof before visiting any module.
# A diagnostic-only collect-all run never publishes an APPLY authorization.
apply_gate_invalidate_dryrun() {
  local proof
  proof="$(apply_gate_dryrun_proof_path)" || return 1
  rm -f -- "$proof" || return 1
  [[ ! -e "$proof" && ! -L "$proof" ]]
}

apply_gate_dryrun_identity() {
  local commit config plan hardware
  commit="$(repo_commit)" || return 1
  config="$(effective_config_sha256)" || return 1
  plan="$(module_plan_sha256)" || return 1
  hardware="$(evidence_hardware_fingerprint)" || return 1
  [[ "$commit" =~ ^[0-9a-f]{40}$ && "$config" =~ ^[0-9a-f]{64}$ &&
     "$plan" =~ ^[0-9a-f]{64}$ && -n "$hardware" ]] || return 1
  printf 'commit=%s\neffective_config_sha256=%s\nmodule_plan_sha256=%s\nhardware_fingerprint=%s\n' \
    "$commit" "$config" "$plan" "$hardware"
}

apply_gate_complete_dryrun() {
  local before="$1" after proof commit
  after="$(apply_gate_dryrun_identity)" || return 1
  [[ -n "$before" && "$after" == "$before" ]] || return 1
  apply_gate_require_clean_git || return 1
  commit="$(repo_commit)" || return 1
  [[ "$commit" =~ ^[0-9a-f]{40}$ && "$before" == "commit=$commit"$'\n'* ]] || return 1
  proof="$STATE_ROOT/dryrun-$commit.ok"
  {
    printf 'verdict=PASS\nrun_id=%s\nutc=%s\n' "$RUN_ID" "$(date -u +%FT%TZ)"
    printf '%s\n' "$before"
  } | evidence_atomic_write "$proof" 0600 || return 1
  if ! apply_gate_require_dryrun; then
    rm -f -- "$proof" || return 1
    return 1
  fi
}

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

apply_gate_require_runtime() { runtime_is_baremetal && ! runtime_is_live; }

apply_gate_require_clean_git() {
  local status
  is_true "${REQUIRE_CLEAN_GIT:-true}" || return 0
  # A Git failure (not a checkout, unsafe ownership) is not a clean tree.
  status="$(git -C "$REPO_ROOT" status --porcelain)" || return 1
  [[ -z "$status" ]]
}

apply_gate_require_live_proof() { validation_require_imported_gate 2; }

apply_gate_require_dryrun() {
  is_true "${REQUIRE_SAME_COMMIT_DRYRUN:-true}" || return 0
  local proof
  proof="$(apply_gate_dryrun_proof_path)"
  [[ -f "$proof" && ! -L "$proof" && -s "$proof" ]] || return 1
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
    ui_error "REAL APPLY is forbidden outside bare-metal or from a Live USB session; install Fedora and reboot first; detected runtime=$(runtime_environment)"
    return "$EXIT_SECURITY_BLOCK"
  }
  fedora_require_install_target || {
    ui_error 'Production APPLY requires running Fedora 45 with HOST_RELEASE=45 and a promoted, authenticated Fedora 45 profile; Fedora 44 and pending Fedora 45 are blocked.'
    return "$EXIT_SECURITY_BLOCK"
  }
  is_true "${REAL_APPLY_FEATURE_ENABLED:-false}" || { ui_error 'REAL APPLY feature disabled'; return "$EXIT_SECURITY_BLOCK"; }
  is_true "${REAL_MACHINE_APPROVED:-false}" || { ui_error 'REAL_MACHINE_APPROVED=false; use config/local.conf after reviewing the target machine'; return "$EXIT_SECURITY_BLOCK"; }
  [[ -t 0 && -t 1 ]] || { ui_error 'interactive TTY required'; return "$EXIT_SECURITY_BLOCK"; }
  apply_gate_require_clean_git || { ui_error 'Git working tree must be clean'; return "$EXIT_SECURITY_BLOCK"; }
  apply_gate_require_live_proof || { ui_error 'Gate 2 imported Live USB proof missing, incomplete, altered or stale for the current commit, module plan or physical hardware; run validate import with the matching proof'; return "$EXIT_SECURITY_BLOCK"; }
  apply_gate_require_dryrun || { ui_error 'dry-run proof is missing/stale for the current commit, effective configuration, module plan or hardware fingerprint'; return "$EXIT_SECURITY_BLOCK"; }
  apply_gate_require_baseline || { ui_error 'hardware baseline certification missing or invalid for the current hardware/BIOS fingerprint'; return "$EXIT_SECURITY_BLOCK"; }
  apply_gate_require_backup || { ui_error 'pre-APPLY Borg archive is missing, stale, no longer readable, or does not match current commit/config/hardware'; return "$EXIT_SECURITY_BLOCK"; }
  local answer
  [[ -n "${APPLY_CONFIRMATION:-}" ]] || { ui_error 'APPLY_CONFIRMATION is empty; an empty answer cannot approve a real APPLY'; return "$EXIT_SECURITY_BLOCK"; }
  printf 'Type exactly "%s": ' "$APPLY_CONFIRMATION"
  read -r answer
  [[ "$answer" == "$APPLY_CONFIRMATION" ]] || return "$EXIT_SECURITY_BLOCK"
}

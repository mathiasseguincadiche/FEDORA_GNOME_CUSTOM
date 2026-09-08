#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap

POLICY="$REPO_ROOT/config/log-retention.policy"
mode="${1:---dry-run}"
[[ "$mode" == --dry-run || "$mode" == --apply ]] || { echo 'Usage: prune-project-evidence.sh [--dry-run|--apply]' >&2; exit "$EXIT_USAGE"; }
[[ -r "$POLICY" ]] || { ui_error "Missing retention policy: $POLICY"; exit "$EXIT_CONFIG_FAILED"; }

policy_value() {
  awk -F= -v key="$1" '$1==key {print $2; exit}' "$POLICY"
}

log_days="$(policy_value log_retention_days)"
report_days="$(policy_value report_retention_days)"
protect_state="$(policy_value protect_state)"
protect_releases="$(policy_value protect_releases)"
protect_referenced="$(policy_value protect_referenced)"

[[ "$log_days" =~ ^[0-9]+$ && "$report_days" =~ ^[0-9]+$ ]] || { ui_error 'Retention days must be integers'; exit "$EXIT_CONFIG_FAILED"; }
(( log_days >= 7 && report_days >= 30 )) || { ui_error 'Retention policy is unexpectedly aggressive'; exit "$EXIT_CONFIG_FAILED"; }
[[ "$protect_state" == true && "$protect_releases" == true ]] || { ui_error 'Golden state/releases must remain protected'; exit "$EXIT_CONFIG_FAILED"; }

is_state_referenced() {
  local candidate="$1" base
  [[ "$protect_referenced" == true ]] || return 1
  base="$(basename "$candidate")"
  [[ -d "$STATE_ROOT" ]] || return 1
  grep -RFl -- "$candidate" "$STATE_ROOT" >/dev/null 2>&1 && return 0
  grep -RFl -- "$base" "$STATE_ROOT" >/dev/null 2>&1 && return 0
  return 1
}

prune_candidates() {
  local root="$1" kind="$2" days="$3" find_type="$4"
  local candidate count=0 protected=0
  [[ -d "$root" ]] || { ui_check EXPECTED "$kind retention" "$root absent"; return 0; }

  while IFS= read -r -d '' candidate; do
    [[ "$candidate" == "$root"/* ]] || { ui_error "Unsafe retention candidate escaped root: $candidate"; exit "$EXIT_SECURITY_BLOCK"; }
    if is_state_referenced "$candidate"; then
      ((protected+=1))
      printf 'PROTECTED %s\n' "$candidate"
      continue
    fi
    ((count+=1))
    if [[ "$mode" == --apply ]]; then
      if [[ "$find_type" == d ]]; then
        rm -rf -- "$candidate"
      else
        rm -f -- "$candidate"
      fi
      printf 'REMOVED %s\n' "$candidate"
    else
      printf 'WOULD_REMOVE %s\n' "$candidate"
    fi
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type "$find_type" -mtime "+$days" -print0)

  ui_meta "$kind candidates" "$count"
  ui_meta "$kind protected references" "$protected"
}

ui_banner 'PROJECT EVIDENCE RETENTION' "${mode#--}"
ui_meta Policy "$POLICY"
ui_meta 'Log retention' "${log_days} days"
ui_meta 'Report retention' "${report_days} days"
ui_check OK 'Golden state' 'state/ is never deleted by this helper'
ui_check OK 'Golden releases' 'state/releases/ is never deleted by this helper'

prune_candidates "$LOG_ROOT" logs "$log_days" d
prune_candidates "$REPORT_ROOT" reports "$report_days" f

if [[ "$mode" == --dry-run ]]; then
  ui_summary 'RETENTION DRY RUN COMPLETE' 'NO FILE WAS DELETED — USE --apply ONLY AFTER REVIEW' "$REPORT_ROOT" "$LOG_DIR"
else
  ui_summary 'RETENTION COMPLETE' 'ONLY OLD UNREFERENCED LOGS/REPORTS WERE REMOVED' "$REPORT_ROOT" "$LOG_DIR"
fi

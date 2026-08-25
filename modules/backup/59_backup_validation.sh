#!/usr/bin/env bash
set -Eeuo pipefail
backup_validation_precheck() { [[ -r "$REPO_ROOT/diagnostics/backup-doctor" ]]; }
backup_validation_plan() { echo 'Validate fail-closed backup/recovery policy, Restic tooling and protected recovery helpers. Repository runtime checks are performed by backup-doctor outside dry-run.'; }
backup_validation_apply() { :; }
backup_validation_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  bash "$REPO_ROOT/diagnostics/backup-doctor" --policy-only
}

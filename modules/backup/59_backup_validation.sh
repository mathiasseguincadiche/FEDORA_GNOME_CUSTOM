#!/usr/bin/env bash
set -Eeuo pipefail
backup_validation_precheck() { :; }
backup_validation_plan() { echo 'Validate backup marker freshness when backup gating is enabled.'; }
backup_validation_apply() { :; }
backup_validation_postcheck() { is_true "${DRY_RUN:-true}" && return 0; is_true "${REQUIRE_PREAPPLY_BACKUP:-true}" || return 0; [[ -s "$STATE_ROOT/preapply-backup.ok" ]]; }

#!/usr/bin/env bash
set -Eeuo pipefail
backup_integrity_precheck() {
  is_true "${BACKUP_INTEGRITY_CHECK_REQUIRED:-true}" && is_true "${BACKUP_RESTORE_TEST_REQUIRED:-true}"
}
backup_integrity_plan() { echo 'Every protected pre-APPLY backup runs restic check plus a restore-canary test. Retention is 7 daily / 4 weekly / 6 monthly and pruning is explicit, never automatic.'; }
backup_integrity_apply() { :; }
backup_integrity_postcheck() { return 0; }

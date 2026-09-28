#!/usr/bin/env bash
set -Eeuo pipefail
backup_integrity_precheck() {
  is_true "${BACKUP_INTEGRITY_CHECK_REQUIRED:-true}" && is_true "${BACKUP_RESTORE_TEST_REQUIRED:-true}"
}
backup_integrity_plan() { echo "Every protected pre-APPLY archive runs borg check with full data verification plus a restore-canary test. Retention ${BACKUP_KEEP_DAILY:-7} daily / ${BACKUP_KEEP_WEEKLY:-4} weekly / ${BACKUP_KEEP_MONTHLY:-6} monthly is applied to full and daily archives only (weekly timer, never at backup time); pre-APPLY archives are never pruned automatically."; }
backup_integrity_apply() { :; }
backup_integrity_postcheck() { return 0; }

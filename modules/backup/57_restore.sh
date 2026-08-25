#!/usr/bin/env bash
set -Eeuo pipefail
backup_restore_precheck() { [[ -x "$REPO_ROOT/scripts/backup/restore.sh" || -r "$REPO_ROOT/scripts/backup/restore.sh" ]]; }
backup_restore_plan() { echo 'Restore workflow is staging-first: list/verify/restore into an operator-selected empty directory; no automatic in-place overwrite of host or active VM storage.'; }
backup_restore_apply() { :; }
backup_restore_postcheck() { [[ -r "$REPO_ROOT/scripts/backup/restore.sh" ]]; }

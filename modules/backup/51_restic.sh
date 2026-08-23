#!/usr/bin/env bash
set -Eeuo pipefail
backup_restic_precheck() { :; }
backup_restic_plan() { echo 'Restic operational module is intentionally non-destructive during normal convergence; use prepare-preapply-backup.sh for explicit protected capture.'; }
backup_restic_apply() { :; }
backup_restic_postcheck() { :; }

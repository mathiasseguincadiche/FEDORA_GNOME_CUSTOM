#!/usr/bin/env bash
set -Eeuo pipefail
backup_repository_precheck() {
  [[ "${BACKUP_ENGINE:-restic}" == restic ]] || return "$EXIT_PRECHECK_FAILED"
  is_true "${BACKUP_ENCRYPTION_REQUIRED:-true}" || return "$EXIT_PRECHECK_FAILED"
  is_true "${BACKUP_REQUIRE_EXTERNAL_TARGET:-true}" || return "$EXIT_PRECHECK_FAILED"
}
backup_repository_plan() { echo 'Restic repository is selected/proven at runtime; local pre-APPLY repositories must resolve to an external USB/removable/hotplug filesystem.'; }
backup_repository_apply() { :; }
backup_repository_postcheck() { command_exists restic || return "$EXIT_POSTCHECK_FAILED"; }

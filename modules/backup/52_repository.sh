#!/usr/bin/env bash
set -Eeuo pipefail
# Borg 1.x, unencrypted repository by explicit owner decision (ADR 0014).
backup_repository_precheck() {
  [[ "${BACKUP_ENGINE:-borg}" == borg ]] || return "$EXIT_PRECHECK_FAILED"
  [[ "${BACKUP_ENCRYPTION:-none}" == none ]] || return "$EXIT_PRECHECK_FAILED"
  is_true "${BACKUP_REQUIRE_EXTERNAL_TARGET:-true}" || return "$EXIT_PRECHECK_FAILED"
}
backup_repository_plan() { echo 'The Borg repository (unencrypted, ADR 0014) is selected/proven at runtime; local pre-APPLY repositories must resolve to an external USB/removable/hotplug filesystem.'; }
backup_repository_apply() { :; }
backup_repository_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  command_exists borg || return "$EXIT_POSTCHECK_FAILED"
  borg --version 2>/dev/null | grep -Eq '^borg 1\.(2|3|4)\.' || return "$EXIT_POSTCHECK_FAILED"
}

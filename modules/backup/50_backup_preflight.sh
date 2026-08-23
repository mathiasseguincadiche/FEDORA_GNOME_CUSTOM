#!/usr/bin/env bash
set -Eeuo pipefail
backup_preflight_precheck() { command_exists dnf; }
backup_preflight_plan() { echo 'Install Restic tooling. Repository credentials remain external to Git; no backup target is invented automatically.'; }
backup_preflight_apply() { run_mutating BACKUP sudo dnf -y install restic; }
backup_preflight_postcheck() { is_true "${DRY_RUN:-true}" && return 0; command_exists restic; }

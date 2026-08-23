#!/usr/bin/env bash
set -Eeuo pipefail
system_updates_precheck() { command_exists dnf; }
system_updates_plan() { echo 'Refresh Fedora metadata and converge all installed RPM packages to current Fedora 44 updates.'; }
system_updates_apply() { run_mutating SYSTEM sudo dnf -y upgrade --refresh; }
system_updates_postcheck() { is_true "${DRY_RUN:-true}" && return 0; sudo dnf -q check; }

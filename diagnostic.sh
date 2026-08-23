#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
DRY_RUN=true
export DRY_RUN
ui_banner 'FEDORA WORKSTATION CONTROL' 'DIAGNOSTIC GLOBAL — READ ONLY'
"$REPO_ROOT/diagnostics/workstation-doctor" --summary

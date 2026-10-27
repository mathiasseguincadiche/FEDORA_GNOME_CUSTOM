#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/validation_gates.sh"

ui_banner 'NATIVE FEDORA VALIDATION' 'LIVE USB / INSTALLED SYSTEM'
validation_pipeline_status
printf '\nOperator path: native Live USB checks -> installation -> installed-system qualification.\n'
printf 'Software quality is verified independently by the GitHub CI of the exact commit.\n'

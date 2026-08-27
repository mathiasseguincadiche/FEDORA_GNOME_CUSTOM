#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
DRY_RUN=true
export DRY_RUN

case "$RUNTIME_ENVIRONMENT" in
  wsl2)
    exec "$REPO_ROOT/diagnostics/wsl2-doctor" --summary
    ;;
  ci)
    ui_banner 'FEDORA WORKSTATION CONTROL' 'CI RUNTIME DETECTED'
    ui_meta Runtime "$RUNTIME_ENVIRONMENT"
    ui_check EXPECTED 'Bare-metal runtime' 'not certifiable inside CI; use repository workflows for automated evidence'
    ui_summary 'CI ENVIRONMENT DETECTED' 'USE GITHUB ACTIONS EVIDENCE' "$REPORT_ROOT" "$LOG_DIR"
    ;;
  baremetal)
    ui_banner 'FEDORA WORKSTATION CONTROL' 'DIAGNOSTIC GLOBAL — READ ONLY'
    exec "$REPO_ROOT/diagnostics/workstation-doctor" --summary
    ;;
  *)
    ui_error "Unknown runtime environment: $RUNTIME_ENVIRONMENT"
    exit "$EXIT_CONFIG_FAILED"
    ;;
esac

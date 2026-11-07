#!/usr/bin/env bash
# Global read-only diagnosis (./control.sh doctor all). On the physical machine it runs
# diagnostics/workstation-doctor --summary; in CI, a VM or a container it reports that
# hardware certification is not possible there.
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
DRY_RUN=true
export DRY_RUN

case "$RUNTIME_ENVIRONMENT" in
  ci)
    ui_banner 'FEDORA WORKSTATION CONTROL' 'CI RUNTIME DETECTED'
    ui_meta Runtime "$RUNTIME_ENVIRONMENT"
    ui_check EXPECTED 'Bare-metal runtime' 'not certifiable inside CI; use repository workflows for automated evidence'
    ui_summary 'CI ENVIRONMENT DETECTED' 'USE GITHUB ACTIONS EVIDENCE' "$REPORT_ROOT" "$LOG_DIR"
    ;;
  wsl2|vm|container)
    ui_banner 'FEDORA WORKSTATION CONTROL' 'VIRTUALIZED RUNTIME DETECTED'
    ui_meta Runtime "$RUNTIME_ENVIRONMENT"
    ui_check KO 'Environnement physique' 'Certification et APPLY réels interdits en VM ou conteneur'
    ui_summary 'ENVIRONNEMENT VIRTUALISÉ — DIAGNOSTIC NON VALIDÉ' 'UTILISER LE DRY-RUN OU LA CI ; QUALIFIER SUR LE PC PHYSIQUE' "$REPORT_ROOT" "$LOG_DIR"
    exit "$EXIT_PRECHECK_FAILED"
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

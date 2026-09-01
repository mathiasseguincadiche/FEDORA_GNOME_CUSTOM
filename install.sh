#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:---dry-run}"
[[ "$MODE" == '--dry-run' || "$MODE" == '--apply' ]] || { echo "Usage: $0 [--dry-run|--apply]" >&2; exit 2; }
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
module_catalog_load "$REPO_ROOT/manifests/module-plan.conf"
module_catalog_validate

if [[ "$MODE" == '--dry-run' ]]; then
  DRY_RUN=true; export DRY_RUN
  ui_banner 'FEDORA WORKSTATION CONTROL' 'NON-MUTATING PREFLIGHT / CONVERGENCE PLAN'
  if orchestrator_run_all; then
    apply_gate_write_dryrun_proof
    report="$(orchestrator_report)"
    ui_summary 'PREFLIGHT PASS' 'NO MUTATIONS EXECUTED — PREPARE VERIFIED BACKUP, THEN APPLY' "$report" "$LOG_DIR"
    exit 0
  else
    rc=$?
    report="$(orchestrator_report)"
    ui_summary "PREFLIGHT FAIL rc=$rc" 'FIX BEFORE APPLY' "$report" "$LOG_DIR"
    exit "$rc"
  fi
fi

DRY_RUN=false; export DRY_RUN
ui_banner 'FEDORA WORKSTATION CONTROL' 'PROTECTED REAL APPLY'
apply_gate_open
orchestrator_run_all
report="$(orchestrator_report)"
ui_summary 'REAL APPLY COMPLETED' 'RUN ./diagnostic.sh AND REBOOT WHEN REQUESTED' "$report" "$LOG_DIR"

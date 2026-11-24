#!/usr/bin/env bash
# Explicit incident review; never restores in place, deletes Borg data or resumes APPLY.
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/apply_incident.sh"
[[ $# -eq 1 ]] || { echo 'Usage: apply-incident.sh status|acknowledge' >&2; exit 2; }
active="$(apply_incident_active)"
case "$1" in
  status)
    if apply_incident_require_clear; then echo 'No recorded pending APPLY incident'; exit 0; fi
    [[ -f "$active" && ! -L "$active" ]] || exit 50
    cat -- "$active"
    ;;
  acknowledge)
    source "$REPO_ROOT/lib/install_lock.sh"
    install_lock_acquire
    source "$REPO_ROOT/lib/bootstrap.sh"
    engine_bootstrap
    [[ -t 0 && -t 1 && -f "$active" && ! -L "$active" && -s "$active" ]] || exit 50
    runtime_is_baremetal && ! runtime_is_live || exit 50
    backup_runtime_validate_preapply_marker "$active" || { echo 'Original Borg rollback point unavailable; do not resume' >&2; exit 50; }
    archive="$(evidence_marker_value "$active" archive)"
    # Re-read the actual original archive before recording operator review.
    backup_engine_check preapply "$archive" || exit 50
    cat -- "$active"
    echo 'Review logs, diagnose partial mutations and inspect recovery in staging first.'
    echo 'Acknowledgment records your review only; it does not certify repair or restore the system.'
    printf 'Type exactly "INCIDENT REVIEWED %s": ' "$archive"
    read -r answer
    [[ "$answer" == "INCIDENT REVIEWED $archive" ]] || exit 50
    apply_incident_close operator-reviewed || exit 50
    echo 'Incident review recorded. Fresh Gate 2 as required, baseline, dry-run, backup and APPLY confirmation remain mandatory.'
    ;;
  *) echo 'Usage: apply-incident.sh status|acknowledge' >&2; exit 2;;
esac

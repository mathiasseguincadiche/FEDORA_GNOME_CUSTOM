#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/validation_gates.sh"

usage() {
  cat <<'TXT'
Usage: ./control.sh validate live [plan|run|status]
  plan    Show the native Live USB checks without running them.
  run     Observe this PC, collect explicit human answers and save a portable record.
  status  Show the local/imported Live record for this source and hardware.

After a successful run, save the record outside the temporary Live session:
  ./control.sh validate export live /path/to/writable/external-support
After installation, clone the same source and import the saved JSON:
  ./control.sh validate import /path/to/live-COMMIT.json
TXT
}

live_run() {
  local report proof
  validation_require_live_runtime || return $?
  # Invalidate both local forms before a new attempt, including failed prechecks.
  rm -f "$(validation_gate_proof_path 2)" "$(validation_imported_proof_path 2)"
  validation_require_clean_source || return $?
  report="$(validation_root)/live-preflight.tsv"
  mkdir -p "$(dirname "$report")"
  if ! bash "$REPO_ROOT/diagnostics/live-preflight.sh" | tee "$report"; then
    ui_error "Live checks are incomplete or failed; review $report"
    return "$EXIT_PRECHECK_FAILED"
  fi
  proof="$(validation_write_live_proof "$report")" || return $?
  ui_check OK 'Live USB compatibility record' "$proof"
  printf '\nSave this JSON outside the Live HOME before rebooting. The session is temporary.\n'
  printf 'This records pre-installation observations only; installed services and Rocky remain to qualify.\n'
}

case "${1:-plan}" in
  plan)
    usage
    printf '\nCHECK\tREQUIREMENT\tEVIDENCE\n'
    live_check_catalog
    ;;
  run) live_run ;;
  status)
    ui_banner 'LIVE USB PRE-INSTALLATION' 'CURRENT SOURCE AND PHYSICAL IDENTITIES'
    printf 'live_usb=%s\n' "$(validation_gate_state 2)"
    ;;
  -h|--help) usage ;;
  *) usage >&2; exit "$EXIT_USAGE" ;;
esac

#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/validation_gates.sh"

[[ $# -eq 2 ]] || { echo 'Usage: scripts/validation/export-proof.sh GATE DESTINATION_DIR' >&2; exit "$EXIT_USAGE"; }
case "$1" in 1|2) ;; *) echo 'GATE must be 1 or 2' >&2; exit "$EXIT_USAGE" ;; esac
validation_require_clean_source || exit $?
exported="$(validation_export_proof "$1" "$2")" || {
  ui_error "No current Gate $1 proof is available to export"
  exit "$EXIT_PRECHECK_FAILED"
}
ui_check OK "Gate $1 proof exported" "$exported"
ui_meta SHA256 "$(validation_file_sha256 "$exported")"

#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/validation_gates.sh"

[[ $# -eq 1 ]] || { echo 'Usage: scripts/validation/import-proof.sh PROOF.json' >&2; exit "$EXIT_USAGE"; }
validation_require_clean_source || exit $?
destination="$(validation_import_proof "$1")" || exit $?
ui_check OK 'Validation proof imported' "$destination"
ui_meta SHA256 "$(validation_file_sha256 "$destination")"

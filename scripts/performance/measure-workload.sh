#!/usr/bin/env bash
# Collect comparable workload timings only after workstation qualification.
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
source "$REPO_ROOT/lib/validation_gates.sh"
if [[ "${1:-}" == --help ]]; then
  echo 'Usage: measure-workload.sh LABEL REPETITIONS -- COMMAND [ARG ...]'
  echo 'Run after Gate 3; writes timings and provenance, never changes tuning.'
  exit 0
fi
[[ $# -ge 4 && "$1" =~ ^[A-Za-z0-9_.-]+$ && "$2" =~ ^[0-9]+$ && "$3" == -- ]] || exit "$EXIT_USAGE"
label="$1"; repetitions="$2"; shift 3
(( repetitions >= 3 && repetitions <= 30 )) || { ui_error 'Use 3 to 30 repetitions'; exit "$EXIT_USAGE"; }
validation_final_certificate_valid || { ui_error 'Current Gate 3 certificate required before optimization measurements'; exit "$EXIT_PRECHECK_FAILED"; }
output="$REPORT_ROOT/$RUN_ID-measure-$label"
python3 "$REPO_ROOT/scripts/performance/measure-workload.py" "$output" "$label" "$repetitions" \
  "$(repo_commit)" "$(effective_config_sha256)" "$(workstation_runtime_fingerprint)" "$@"

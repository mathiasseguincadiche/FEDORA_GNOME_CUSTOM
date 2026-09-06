#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/validation_gates.sh"

usage() {
  cat <<'EOF'
Usage: scripts/validation/gate3-baremetal.sh [status|record-suspend|certify]

status          Verify imported Gate 1/Gate 2 chain and show final-certification status.
record-suspend  Record one physical suspend/resume cycle after verifying the gate chain.
certify         Run the complete bare-metal Golden certification.

Before Gate 3, import both proofs in order:
  ./control.sh validate import /path/to/gate1-<commit>.json
  ./control.sh validate import /path/to/gate2-<commit>.json
EOF
}

gate3_require_runtime() {
  runtime_is_baremetal || {
    ui_error "Gate 3 is bare-metal only; detected runtime=$(runtime_environment)"
    return "$EXIT_SECURITY_BLOCK"
  }
  validation_require_fedora44 || {
    ui_error 'Gate 3 requires Fedora Linux 44'
    return "$EXIT_PRECHECK_FAILED"
  }
  validation_require_clean_source || return $?
  validation_require_chain || {
    ui_error 'Gate 3 requires a current Gate 1 → Gate 2 proof chain for this commit/module plan'
    return "$EXIT_PRECHECK_FAILED"
  }
}

gate3_status() {
  gate3_require_runtime || return $?
  ui_banner 'GATE 3 — BARE-METAL' 'GOLDEN CERTIFICATION STATUS'
  ui_check OK 'Gate 1 → Gate 2 chain' 'current and cryptographically linked'
  ui_meta 'Gate 1 SHA256' "$(validation_file_sha256 "$(validation_imported_proof_path 1)")"
  ui_meta 'Gate 2 SHA256' "$(validation_file_sha256 "$(validation_imported_proof_path 2)")"
  "$REPO_ROOT/diagnostics/final-certification" status
}

gate3_record_suspend() {
  gate3_require_runtime || return $?
  "$REPO_ROOT/diagnostics/final-certification" record-suspend
}

gate3_certify() {
  gate3_require_runtime || return $?
  ui_banner 'GATE 3 — BARE-METAL' 'COMPLETE GOLDEN WORKSTATION CERTIFICATION'
  "$REPO_ROOT/diagnostics/final-certification" certify
}

case "${1:-status}" in
  status) gate3_status ;;
  record-suspend) gate3_record_suspend ;;
  certify) gate3_certify ;;
  -h|--help) usage ;;
  *) usage >&2; exit "$EXIT_USAGE" ;;
esac

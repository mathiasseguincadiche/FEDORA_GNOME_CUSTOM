#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
source "$REPO_ROOT/lib/validation_gates.sh"
usage(){ cat <<'TXT'
Usage: scripts/validation/gate3-baremetal.sh COMMAND
  status | record-suspend | certify
  gpu-soak | network-lan | network-wifi | audio-cert | display-cert | physical-status

Pre-APPLY baseline additions:
  ./diagnostics/baseline-doctor enroll-bluetooth
  ./diagnostics/baseline-doctor list-cooling
  ./diagnostics/baseline-doctor enroll-cooling <pump-fanN> <cpu-fanN> <system-fanN>
  ./diagnostics/baseline-doctor run-cpu-soak

Before Gate 3, import Gate 1 then Gate 2 proofs for the same commit/module plan.
TXT
}
gate3_require_runtime(){ runtime_is_baremetal || { ui_error "Gate 3 is bare-metal only; detected runtime=$(runtime_environment)"; return "$EXIT_SECURITY_BLOCK"; }; validation_require_fedora44 || { ui_error 'Gate 3 requires Fedora Linux 44'; return "$EXIT_PRECHECK_FAILED"; }; validation_require_clean_source || return $?; validation_require_chain || { ui_error 'Gate 3 requires a current Gate 1 → Gate 2 proof chain'; return "$EXIT_PRECHECK_FAILED"; }; }
gate3_status(){ gate3_require_runtime || return $?; ui_banner 'GATE 3 — BARE-METAL' 'GOLDEN CERTIFICATION STATUS'; ui_check OK 'Gate 1 → Gate 2 chain' 'current and cryptographically linked'; "$REPO_ROOT/diagnostics/physical-runtime-doctor" status || true; "$REPO_ROOT/diagnostics/final-certification" status; }
gate3_physical(){ gate3_require_runtime || return $?; "$REPO_ROOT/diagnostics/physical-runtime-doctor" "$@"; }
case "${1:-status}" in
 status) gate3_status ;;
 record-suspend) gate3_require_runtime; "$REPO_ROOT/diagnostics/final-certification" record-suspend ;;
 certify) gate3_require_runtime; ui_banner 'GATE 3 — BARE-METAL' 'COMPLETE GOLDEN WORKSTATION CERTIFICATION'; "$REPO_ROOT/diagnostics/final-certification" certify ;;
 gpu-soak) gate3_physical gpu-soak ;;
 network-lan) gate3_physical network lan ;;
 network-wifi) gate3_physical network wifi ;;
 audio-cert) gate3_physical audio ;;
 display-cert) gate3_physical display-capabilities ;;
 physical-status) gate3_physical status ;;
 -h|--help) usage ;;
 *) usage >&2; exit "$EXIT_USAGE" ;;
esac

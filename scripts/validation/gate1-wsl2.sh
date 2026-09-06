#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/validation_gates.sh"

GATE1_CONTRACT_COUNT=0

usage() {
  cat <<'EOF'
Usage: scripts/validation/gate1-wsl2.sh [run|status]

run     Execute Gate 1 inside Fedora 44 on WSL2 and create a portable PASS proof.
status  Show whether a current Gate 1 proof exists locally.

Gate 1 validates the project/system logic only. Native B580/xe, ReBAR, PCIe,
T705 SMART, EDID, firmware sleep/resume and other physical evidence remain DEFERRED.
EOF
}

gate1_require_runtime() {
  runtime_is_wsl2 || {
    ui_error "Gate 1 requires Fedora 44 under WSL2; detected runtime=$(runtime_environment)"
    return "$EXIT_SECURITY_BLOCK"
  }
  validation_require_fedora44 || {
    ui_error 'Gate 1 requires Fedora Linux 44'
    return "$EXIT_PRECHECK_FAILED"
  }
  validation_require_clean_source
}

gate1_require_tools() {
  local cmd
  local -a missing=()
  for cmd in python3 sha256sum sed sort; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  if ((${#missing[@]} != 0)); then
    ui_error "Gate 1 tooling missing: ${missing[*]}"
    return "$EXIT_PRECHECK_FAILED"
  fi
}

gate1_contract_suite() {
  local workflow="$REPO_ROOT/.github/workflows/tests.yml" test_file count=0
  local -a contract_tests=()
  [[ -r "$workflow" ]] || return "$EXIT_PRECHECK_FAILED"
  mapfile -t contract_tests < <(
    awk '/^[[:space:]]*- run: bash tests\// {sub(/^[[:space:]]*- run: bash /, ""); print $1}' "$workflow"
  )
  ((${#contract_tests[@]} > 0)) || {
    ui_error 'No contract tests could be resolved from .github/workflows/tests.yml'
    return "$EXIT_CONFIG_FAILED"
  }
  for test_file in "${contract_tests[@]}"; do
    printf 'GATE1 CONTRACT [%02d/%02d] %s\n' "$((count + 1))" "${#contract_tests[@]}" "$test_file"
    bash "$REPO_ROOT/$test_file"
    ((count+=1))
  done
  GATE1_CONTRACT_COUNT="$count"
}

gate1_run() {
  local proof
  gate1_require_runtime || return $?
  gate1_require_tools || return $?
  ui_banner 'GATE 1 — WSL2' 'FEDORA 44 SYSTEM / LOGIC PREVALIDATION — HARDWARE DEFERRED'

  "$REPO_ROOT/scripts/config/validate-config.sh" "$REPO_ROOT/config"
  "$REPO_ROOT/diagnostics/wsl2-doctor"
  gate1_contract_suite || return $?
  ((GATE1_CONTRACT_COUNT > 0)) || {
    ui_error 'Gate 1 contract suite did not execute any test'
    return "$EXIT_POSTCHECK_FAILED"
  }

  proof="$(validation_write_proof 1 wsl2 '' N/A "contracts=$GATE1_CONTRACT_COUNT;config=PASS;wsl2_doctor=PASS;physical_hardware=DEFERRED")"
  ui_check OK 'Gate 1 proof' "$proof"
  ui_meta Contracts "$GATE1_CONTRACT_COUNT"
  ui_summary 'GATE 1 PASS' 'EXPORT THIS PROOF TO THE VIRTUALBOX GATE; PHYSICAL HARDWARE IS STILL DEFERRED' "$proof" "$LOG_DIR"
}

gate1_status() {
  local proof
  proof="$(validation_gate_proof_path 1)"
  ui_banner 'GATE 1 — WSL2' 'STATUS'
  if validation_verify_proof "$proof" 1; then
    ui_check OK 'Gate 1 local proof' "$proof"
    ui_meta SHA256 "$(validation_file_sha256 "$proof")"
  else
    ui_check WARN 'Gate 1 local proof' 'missing, stale, or invalid for current commit/module plan'
    return "$EXIT_PRECHECK_FAILED"
  fi
}

case "${1:-run}" in
  run) gate1_run ;;
  status) gate1_status ;;
  -h|--help) usage ;;
  *) usage >&2; exit "$EXIT_USAGE" ;;
esac

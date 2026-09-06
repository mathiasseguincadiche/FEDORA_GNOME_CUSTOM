#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/state" "$tmp/manifests"
printf 'fake module plan\n' > "$tmp/manifests/module-plan.conf"

(
  REPO_ROOT="$tmp"
  STATE_ROOT="$tmp/state"
  RUNTIME_ENVIRONMENT=wsl2
  EXIT_USAGE=2
  EXIT_CONFIG_FAILED=12
  EXIT_PRECHECK_FAILED=20
  EXIT_SECURITY_BLOCK=50

  repo_commit() { printf '1111111111111111111111111111111111111111\n'; }
  module_plan_sha256() { printf '2222222222222222222222222222222222222222222222222222222222222222\n'; }
  effective_config_sha256() { printf '3333333333333333333333333333333333333333333333333333333333333333\n'; }
  runtime_environment() { printf '%s\n' "$RUNTIME_ENVIRONMENT"; }
  runtime_is_vm() { [[ "$RUNTIME_ENVIRONMENT" == vm ]]; }
  apply_gate_require_clean_git() { return 0; }
  ui_error() { printf 'ERROR: %s\n' "$*" >&2; }

  # Make the mock callbacks explicitly reachable to static analysis before the
  # sourced validation library invokes them indirectly.
  [[ "$(module_plan_sha256)" == '2222222222222222222222222222222222222222222222222222222222222222' ]]
  [[ "$(effective_config_sha256)" == '3333333333333333333333333333333333333333333333333333333333333333' ]]
  apply_gate_require_clean_git

  # shellcheck source=lib/evidence.sh
  source "$ROOT/lib/evidence.sh"
  # shellcheck source=lib/validation_gates.sh
  source "$ROOT/lib/validation_gates.sh"

  gate1="$(validation_write_proof 1 wsl2 '' N/A 'contracts=PASS;hardware=DEFERRED')"
  validation_verify_proof "$gate1" 1
  imported1="$(validation_import_proof "$gate1")"
  [[ -s "$imported1" ]]

  gate1_hash="$(validation_file_sha256 "$imported1")"
  gate2="$(validation_write_proof 2 virtualbox "$gate1_hash" PASS 'desktop=PASS;manual_visual=PASS;hardware=DEFERRED')"
  validation_verify_proof "$gate2" 2
  imported2="$(validation_import_proof "$gate2")"
  [[ -s "$imported2" ]]
  validation_require_chain

  # A Gate 2 proof linked to another Gate 1 proof must be rejected.
  forged_gate2="$(validation_write_proof 2 virtualbox 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' PASS 'desktop=PASS')"
  if validation_import_proof "$forged_gate2" >/dev/null 2>&1; then
    echo 'Gate 2 accepted a mismatched Gate 1 predecessor' >&2
    exit 1
  fi

  # Even harmless JSON whitespace changes the Gate 1 artifact hash and must
  # invalidate the Gate 1 -> Gate 2 cryptographic chain.
  printf '\n' >> "$imported1"
  validation_verify_proof "$imported1" 1
  if validation_require_chain; then
    echo 'Gate chain remained valid after Gate 1 artifact hash changed' >&2
    exit 1
  fi

  # Gate 1/2 proof contents must always remain explicitly non-hardware evidence.
  python3 - "$gate1" "$gate2" <<'PY'
import json
import sys
for path in sys.argv[1:]:
    with open(path, encoding='utf-8') as handle:
        data = json.load(handle)
    assert data['hardware_certification'] == 'DEFERRED'
assert json.load(open(sys.argv[1], encoding='utf-8'))['manual_visual'] == 'N/A'
assert json.load(open(sys.argv[2], encoding='utf-8'))['manual_visual'] == 'PASS'
PY
)

echo 'validation gate proof behavior: PASS'

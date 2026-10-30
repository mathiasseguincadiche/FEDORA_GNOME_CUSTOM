#!/usr/bin/env bash
# Native validation specification: removed operator environments stay removed,
# no predecessor VM proof keeps authority, and the Live proof schema. The Live
# run, export, import, Gate 3 routes and their refusals are exercised through
# the real ./control.sh by test_validation_entrypoints_behavior.sh; proof
# serialization by test_validation_gate_proof_behavior.sh and
# test_live_validation_behavior.py.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "native validation contract: FAIL: $*" >&2; exit 1; }

# Obsolete operator paths must not remain callable.
for removed in \
  scripts/validation/gate1-wsl2.sh \
  scripts/validation/gate2-virtualbox.sh \
  scripts/lab/apply-gnome-virtualbox.sh \
  diagnostics/wsl2-doctor \
  diagnostics/virtualbox-gnome-lab-doctor; do
  [[ ! -e "$ROOT/$removed" ]] || fail "obsolete operator entrypoint remains: $removed"
done

# A single native Live record is carried into the installed certificate and
# Golden release. Historical VM predecessor proofs have no active authority.
if grep -Eq 'gate[12]_proof_sha256|gate[12]-proof.json|predecessor_sha256' \
    "$ROOT/lib/validation_gates.sh" "$ROOT/lib/live_validation.py" \
    "$ROOT/diagnostics/final-certification" "$ROOT/scripts/release/capture-golden-release.sh"; then
  fail 'obsolete predecessor proof remains in the active certification contract'
fi

python3 - "$ROOT/manifests/validation-gate-proof.schema.json" <<'PY_SCHEMA'
import json
import sys
schema = json.load(open(sys.argv[1]))
properties = schema['properties']
assert schema['additionalProperties'] is False
assert properties['schema']['const'] == 2
assert properties['environment']['const'] == 'live-usb'
assert properties['hardware_certification']['const'] == 'PREINSTALL_ONLY'
assert {'project_commit', 'module_plan_sha256', 'hardware_fingerprint_sha256',
        'source_tree_clean', 'live_kernel', 'checks'} <= set(schema['required'])
assert not {'predecessor_sha256', 'gate1_proof_sha256', 'gate2_proof_sha256'} & set(properties)
PY_SCHEMA

echo 'native Live USB and installed-system validation contract: PASS'

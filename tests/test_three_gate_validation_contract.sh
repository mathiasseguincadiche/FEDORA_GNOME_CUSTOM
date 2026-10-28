#!/usr/bin/env bash
# Public validation contract: software CI, native Live USB, installed Fedora.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "native validation contract: FAIL: $*" >&2; exit 1; }
# Exercise the real CLI with disposable logging/state. Source directories stay
# read-only and a planning command cannot leave artifacts in the checkout.
temporary="$(mktemp -d)"
trap 'rm -rf -- "$temporary"' EXIT
CLI_ROOT="$temporary/repo"
mkdir -p "$CLI_ROOT/scripts/validation"
cp "$ROOT/control.sh" "$CLI_ROOT/control.sh"
cp "$ROOT/scripts/validation/live-usb.sh" "$CLI_ROOT/scripts/validation/live-usb.sh"
for directory in lib config manifests profiles; do
  ln -s "$ROOT/$directory" "$CLI_ROOT/$directory"
done
ln -s "$ROOT/VERSION" "$CLI_ROOT/VERSION"
ln -s "$ROOT/scripts/config" "$CLI_ROOT/scripts/config"

for file in \
  lib/validation_gates.sh \
  lib/live_validation.py \
  scripts/validation/live-usb.sh \
  scripts/validation/gate3-baremetal.sh \
  scripts/validation/import-proof.sh \
  scripts/validation/export-proof.sh \
  scripts/validation/status.sh \
  manifests/validation-gate-proof.schema.json; do
  [[ -s "$ROOT/$file" ]] || fail "missing native validation artifact: $file"
done

# Obsolete operator paths must not remain callable or enter the public help.
for removed in \
  scripts/validation/gate1-wsl2.sh \
  scripts/validation/gate2-virtualbox.sh \
  scripts/lab/apply-gnome-virtualbox.sh \
  diagnostics/wsl2-doctor \
  diagnostics/virtualbox-gnome-lab-doctor; do
  [[ ! -e "$ROOT/$removed" ]] || fail "obsolete operator entrypoint remains: $removed"
done
for command in gate1 gate2; do
  if bash "$CLI_ROOT/control.sh" validate "$command" plan >/dev/null 2>&1; then
    fail "obsolete validation command accepted: $command"
  fi
done

# The native Live path observes compatibility; it cannot apply or issue a final
# certificate. Golden qualification explicitly requires an installed runtime.
grep -Fq 'validation_require_live_runtime' "$ROOT/scripts/validation/live-usb.sh"
grep -Fq 'validation_write_live_proof' "$ROOT/scripts/validation/live-usb.sh"
grep -Fq 'diagnostics/live-preflight.sh' "$ROOT/scripts/validation/live-usb.sh"
if grep -Eq 'final-certification|capture-golden-release|install.sh.*--apply' "$ROOT/scripts/validation/live-usb.sh"; then
  fail 'Live observations invoke an installed-system action'
fi
grep -Fq 'validation_require_installed_runtime' "$ROOT/scripts/validation/gate3-baremetal.sh"
grep -Fq 'validation_require_chain' "$ROOT/scripts/validation/gate3-baremetal.sh"
grep -Fq 'validation_require_installed_runtime' "$ROOT/diagnostics/final-certification"
grep -Fq 'require_validation_chain' "$ROOT/diagnostics/final-certification"
grep -Fq 'live_proof_sha256=' "$ROOT/diagnostics/final-certification"
grep -Fq 'validation_chain=PASS' "$ROOT/diagnostics/final-certification"

# A single native Live record is carried into the installed certificate and
# Golden release. Historical VM predecessor proofs have no active authority.
grep -Fq 'live-proof.json' "$ROOT/scripts/release/capture-golden-release.sh"
grep -Fq 'live_proof_sha256' "$ROOT/scripts/release/capture-golden-release.sh"
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

# The public planning command must remain read-only and usable outside Fedora.
plan="$(bash "$CLI_ROOT/control.sh" validate live plan)"
grep -Fq 'CHECK' <<< "$plan" || fail 'Live plan omitted its check catalog'
grep -Fq 'validate export live' <<< "$plan" || fail 'Live plan omitted external export'
grep -Fq 'validate import' <<< "$plan" || fail 'Live plan omitted installed import'
for check in session gpu storage display_mode display network; do
  grep -Eq "^${check}[[:space:]]+required[[:space:]]" <<< "$plan" || fail "missing required Live check: $check"
done
help="$(bash "$CLI_ROOT/control.sh" validate help)"
for route in 'validate live' 'validate export live' 'validate import' 'validate gate3'; do
  grep -Fq "$route" <<< "$help" || fail "missing operator route: $route"
done
if grep -Eqi 'wsl2|virtualbox|validate gate[12]' <<< "$help"; then
  fail 'public validation help still prescribes a removed operator environment'
fi

echo 'native Live USB and installed-system validation contract: PASS'

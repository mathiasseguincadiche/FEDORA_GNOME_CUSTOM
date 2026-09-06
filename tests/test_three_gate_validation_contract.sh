#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for file in \
  lib/validation_gates.sh \
  scripts/validation/gate1-wsl2.sh \
  scripts/validation/gate2-virtualbox.sh \
  scripts/validation/gate3-baremetal.sh \
  scripts/validation/import-proof.sh \
  scripts/validation/export-proof.sh \
  scripts/validation/status.sh \
  manifests/validation-gate-proof.schema.json \
  docs/THREE_GATE_VALIDATION.md \
  docs/adr/0009-three-gate-validation.md; do
  [[ -s "$ROOT/$file" ]] || { echo "missing three-gate artifact: $file" >&2; exit 1; }
done

python3 -m json.tool "$ROOT/manifests/validation-gate-proof.schema.json" >/dev/null

# Gate 1 is WSL2-only and can never manufacture bare-metal certification.
grep -Fq 'runtime_is_wsl2' "$ROOT/scripts/validation/gate1-wsl2.sh"
grep -Fq 'diagnostics/wsl2-doctor' "$ROOT/scripts/validation/gate1-wsl2.sh"
grep -Fq '.github/workflows/tests.yml' "$ROOT/scripts/validation/gate1-wsl2.sh"
grep -Fq 'physical_hardware=DEFERRED' "$ROOT/scripts/validation/gate1-wsl2.sh"
grep -Fq 'python3 sha256sum sed sort' "$ROOT/scripts/validation/gate1-wsl2.sh"
if grep -Fq 'final-certification' "$ROOT/scripts/validation/gate1-wsl2.sh"; then
  echo 'Gate 1 must never invoke final-certification' >&2
  exit 1
fi
if grep -Fq 'capture-golden-release.sh' "$ROOT/scripts/validation/gate1-wsl2.sh"; then
  echo 'Gate 1 must never capture a Golden release' >&2
  exit 1
fi

# Gate 2 requires Gate 1, VirtualBox, automated desktop doctors and human visual sign-off.
grep -Fq 'runtime_is_virtualbox' "$ROOT/scripts/validation/gate2-virtualbox.sh"
grep -Fq 'validation_require_imported_gate 1' "$ROOT/scripts/validation/gate2-virtualbox.sh"
grep -Fq 'JE_VALIDE_VISUELLEMENT_GATE2' "$ROOT/scripts/validation/gate2-virtualbox.sh"
grep -Fq 'nautilus-integration-doctor' "$ROOT/scripts/validation/gate2-virtualbox.sh"
grep -Fq 'ptyxis-doctor' "$ROOT/scripts/validation/gate2-virtualbox.sh"
grep -Fq 'portal-doctor' "$ROOT/scripts/validation/gate2-virtualbox.sh"
grep -Fq 'predecessor' "$ROOT/scripts/validation/gate2-virtualbox.sh"
if grep -Fq 'final-certification' "$ROOT/scripts/validation/gate2-virtualbox.sh"; then
  echo 'Gate 2 must never invoke final-certification' >&2
  exit 1
fi

# The VirtualBox LAB now converges the actual Nautilus and GTK4/Ptyxis desktop subset.
grep -Fq 'modules/gnome/20_gnome_core.sh' "$ROOT/scripts/lab/apply-gnome-virtualbox.sh"
grep -Fq 'modules/gnome/21_nautilus_integration.sh' "$ROOT/scripts/lab/apply-gnome-virtualbox.sh"
grep -Fq 'modules/applications/40_gtk4_native_apps.sh' "$ROOT/scripts/lab/apply-gnome-virtualbox.sh"
grep -Fq 'gnome_nautilus_apply' "$ROOT/scripts/lab/apply-gnome-virtualbox.sh"
grep -Fq 'applications_gtk4_apply' "$ROOT/scripts/lab/apply-gnome-virtualbox.sh"
grep -Fq 'ptyxis-doctor' "$ROOT/scripts/lab/apply-gnome-virtualbox.sh"

# Portable proofs are bound to commit/module-plan and Gate 2 must hash-link Gate 1.
grep -Fq 'project_commit' "$ROOT/lib/validation_gates.sh"
grep -Fq 'module_plan_sha256' "$ROOT/lib/validation_gates.sh"
grep -Fq 'hardware_certification' "$ROOT/lib/validation_gates.sh"
grep -Fq 'DEFERRED' "$ROOT/lib/validation_gates.sh"
grep -Fq 'predecessor_sha256' "$ROOT/lib/validation_gates.sh"
grep -Fq 'validation_require_chain' "$ROOT/lib/validation_gates.sh"

# Gate 3 and the underlying final-certification independently enforce the chain.
grep -Fq 'runtime_is_baremetal' "$ROOT/scripts/validation/gate3-baremetal.sh"
grep -Fq 'validation_require_chain' "$ROOT/scripts/validation/gate3-baremetal.sh"
validation_source="source \"\$REPO_ROOT/lib/validation_gates.sh\""
grep -Fq "$validation_source" "$ROOT/diagnostics/final-certification"
grep -Fq 'require_validation_chain' "$ROOT/diagnostics/final-certification"
grep -Fq 'gate1_proof_sha256=' "$ROOT/diagnostics/final-certification"
grep -Fq 'gate2_proof_sha256=' "$ROOT/diagnostics/final-certification"
grep -Fq 'validation_chain=PASS' "$ROOT/diagnostics/final-certification"

# Golden release embeds the two portable proofs and their hashes.
grep -Fq 'gate1-proof.json' "$ROOT/scripts/release/capture-golden-release.sh"
grep -Fq 'gate2-proof.json' "$ROOT/scripts/release/capture-golden-release.sh"
grep -Fq 'validation_gates' "$ROOT/scripts/release/capture-golden-release.sh"
grep -Fq 'gate1_proof_sha256' "$ROOT/scripts/release/capture-golden-release.sh"
grep -Fq 'gate2_proof_sha256' "$ROOT/scripts/release/capture-golden-release.sh"

# Operator CLI and documentation expose the same ordered workflow.
grep -Fq 'validate gate1' "$ROOT/control.sh"
grep -Fq 'validate gate2' "$ROOT/control.sh"
grep -Fq 'validate gate3' "$ROOT/control.sh"
grep -Fq 'THREE_GATE_VALIDATION.md' "$ROOT/README.md"
grep -Fq 'Gate 1' "$ROOT/docs/THREE_GATE_VALIDATION.md"
grep -Fq 'Gate 2' "$ROOT/docs/THREE_GATE_VALIDATION.md"
grep -Fq 'Gate 3' "$ROOT/docs/THREE_GATE_VALIDATION.md"

echo 'three-gate validation contract: PASS'

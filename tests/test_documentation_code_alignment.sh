#!/usr/bin/env bash
# shellcheck disable=SC2016
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "documentation/code alignment: $*" >&2; exit 1; }
require_file() { [[ -s "$ROOT/$1" ]] || fail "missing $1"; }

for file in \
  docs/DOCUMENTATION_MODEL.md \
  docs/RUNBOOK_KVM.md \
  docs/RUNBOOK_PERSISTENT_DATA_GAMING.md \
  docs/KVM_QUICKSTART.md \
  docs/VIRTUALIZATION.md \
  docs/VM_PROFILES.md \
  docs/CONTROL_CENTER.md \
  docs/PERFORMANCE.md \
  docs/GOLDEN_RELEASE.md \
  docs/SUPPLY_CHAIN.md; do
  require_file "$file"
done

# Canonical executable configuration.
# shellcheck source=/dev/null
source "$ROOT/config/virtualization.conf"
# shellcheck source=/dev/null
source "$ROOT/config/vm-profiles.conf"
# shellcheck source=/dev/null
source "$ROOT/config/gaming.conf"

# KVM reference values must be visible in every operator/reference document that
# can be used to create or inspect the Rocky guest.
for doc in docs/KVM_QUICKSTART.md docs/VIRTUALIZATION.md docs/VM_PROFILES.md; do
  grep -Fq "$LIBVIRT_URI" "$ROOT/$doc" || fail "$doc missing LIBVIRT_URI=$LIBVIRT_URI"
  grep -Fq "$KVM_POOL_NAME" "$ROOT/$doc" || fail "$doc missing pool $KVM_POOL_NAME"
  grep -Fq "$KVM_POOL_PATH" "$ROOT/$doc" || fail "$doc missing pool path $KVM_POOL_PATH"
  grep -Fq "$KVM_NETWORK_NAME" "$ROOT/$doc" || fail "$doc missing network $KVM_NETWORK_NAME"
  grep -Fq "$KVM_BRIDGE_NAME" "$ROOT/$doc" || fail "$doc missing bridge $KVM_BRIDGE_NAME"
  grep -Fq "$KVM_NETWORK_CIDR" "$ROOT/$doc" || fail "$doc missing CIDR $KVM_NETWORK_CIDR"
done

# Profile identity/resources must match config/vm-profiles.conf exactly in the
# two normative VM references.
for doc in docs/VIRTUALIZATION.md docs/VM_PROFILES.md; do
  grep -Fq "$ROCKY_SERVER_NAME" "$ROOT/$doc" || fail "$doc missing Rocky domain name"
  grep -Fq "$ROCKY_SERVER_RELEASE" "$ROOT/$doc" || fail "$doc missing Rocky release"
  grep -Fq "vCPU               $ROCKY_SERVER_VCPU" "$ROOT/$doc" || fail "$doc Rocky vCPU drift"
  grep -Fq 'RAM                16 Gio' "$ROOT/$doc" || fail "$doc Rocky RAM drift"
  grep -Fq "disque             $ROCKY_SERVER_DISK_GB Gio qcow2" "$ROOT/$doc" || fail "$doc Rocky disk drift"
done

# Every direct Rocky creation example must pass the real required image option;
# signatures are mandatory even when their paths use the engine's defaults.
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import shlex
import sys

root = Path(sys.argv[1])
engine = root / "scripts/kvm/create_rocky_devops_vm.sh"
supported = set(re.findall(r"^\s*(--[a-z0-9-]+)\)", engine.read_text(), re.M))
engine_docs = ["KVM_QUICKSTART.md", "VIRTUALIZATION.md", "VM_PROFILES.md", "RUNBOOK_KVM.md"]
errors = []


def check_examples(path, command):
    text = path.read_text(encoding="utf-8")
    blocks = re.findall(r"```bash\n(.*?)```", text, flags=re.S)
    examples = [block for block in blocks if command in block]
    if not examples:
        errors.append(f"{path.name}: no executable Rocky creation example")
    for block in examples:
        tokens = shlex.split(block.replace("\\\n", " "), comments=True)
        for index, token in enumerate(tokens):
            if not token.startswith("--"):
                continue
            if token not in supported:
                errors.append(f"{path.name}: unknown Rocky creation option {token}")
            if index + 1 >= len(tokens) or tokens[index + 1].startswith("--"):
                errors.append(f"{path.name}: missing value for {token}")
        if "--cloud-image" not in tokens:
            errors.append(f"{path.name}: missing required --cloud-image")
        else:
            index = tokens.index("--cloud-image")
            if index + 1 >= len(tokens) or not tokens[index + 1].endswith(".qcow2"):
                errors.append(f"{path.name}: --cloud-image must name a qcow2 image")
    return text


for name in engine_docs:
    path = root / "docs" / name
    text = check_examples(path, "scripts/kvm/create_rocky_devops_vm.sh")
    for member in ("CHECKSUM", "CHECKSUM.asc"):
        if member not in text:
            errors.append(f"{name}: authenticated image instructions omit {member}")

check_examples(root / "docs/CONTROL_CENTER.md", "control.sh kvm create-rocky")
if errors:
    for error in errors:
        print(error, file=sys.stderr)
    raise SystemExit(1)
PY

grep -Fq 'ROCKY_SERVER_CLOUD_IMAGE_VERIFICATION_REQUIRED="true"' "$ROOT/config/vm-profiles.conf" \
  || fail 'Rocky image authentication must remain mandatory'
grep -Fq '"$signature" "$sums"' "$ROOT/scripts/kvm/verify_rocky_cloud_image.sh" \
  || fail 'Rocky verifier no longer authenticates the checksum signature'
verify_line="$(grep -n 'bash "$verifier"' "$ROOT/scripts/kvm/create_rocky_devops_vm.sh" | head -n1 | cut -d: -f1)"
convert_line="$(grep -n 'sudo qemu-img convert' "$ROOT/scripts/kvm/create_rocky_devops_vm.sh" | head -n1 | cut -d: -f1)"
[[ "$verify_line" =~ ^[0-9]+$ && "$convert_line" =~ ^[0-9]+$ && "$verify_line" -lt "$convert_line" ]] \
  || fail 'Documented Rocky authentication must run before disk creation'

# The public Rocky route must forward the documented arguments to its engine.
grep -Fq 'if [[ "${1:-}" == kvm ]]' "$ROOT/control.sh" || fail 'public KVM argument routing missing'
grep -Fq 'create_rocky_devops_vm.sh" "$@"' "$ROOT/control.sh" || fail 'Rocky public route does not forward arguments'

# KVM runbook uses the public Control Center routes, which themselves map to the
# real guard actions. This keeps docs stable if implementation details move.
grep -Fq 'guard-check) sudo "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh" check' "$ROOT/lib/control_center.sh" \
  || fail 'Control Center guard-check route drifted'
grep -Fq 'guard-reconcile) sudo "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh" reconcile' "$ROOT/lib/control_center.sh" \
  || fail 'Control Center guard-reconcile route drifted'
grep -Fq './control.sh kvm guard-check' "$ROOT/docs/RUNBOOK_KVM.md" || fail 'KVM runbook missing public guard-check route'
grep -Fq './control.sh kvm guard-reconcile' "$ROOT/docs/RUNBOOK_KVM.md" || fail 'KVM runbook missing public guard-reconcile route'
if grep -Fq 'kvm_network_guard.sh status' "$ROOT/docs/RUNBOOK_KVM.md"; then
  fail 'KVM runbook documents nonexistent guard status action'
fi

# Persistent-data catalogue is four roots everywhere; libvirt remains isolated.
grep -Fq '/data/{Documents,Projets,ISO,Jeux}' "$ROOT/config/virtualization.conf" \
  || fail 'virtualization.conf comment is missing Jeux from the persistent-data catalogue'
grep -Fq '/data/Documents + /data/Projets + /data/ISO + /data/Jeux' "$ROOT/diagnostics/backup-doctor" \
  || fail 'backup-doctor summary does not reflect all four persistent roots'
grep -Fq '/data/Documents + /data/Projets + /data/ISO + /data/Jeux' "$ROOT/diagnostics/desktop-integration-doctor" \
  || fail 'desktop integration summary does not reflect all four persistent roots'
for doc in docs/VIRTUALIZATION.md docs/RUNBOOK_PERSISTENT_DATA_GAMING.md; do
  for path in /data/Documents /data/Projets /data/ISO /data/Jeux /data/libvirt; do
    grep -Fq "$path" "$ROOT/$doc" || fail "$doc missing $path"
  done
done

# Performance is a first-class Golden runtime contract and must stay connected
# across public controls, Gate 3 certification and release evidence.
grep -Fq './control.sh perf status' "$ROOT/docs/CONTROL_CENTER.md" || fail 'Control Center missing performance route'
grep -Fq 'performance_contract=PASS' "$ROOT/diagnostics/final-certification" || fail 'final certificate missing performance contract'
grep -Fq 'performance-runtime.policy' "$ROOT/docs/GOLDEN_RELEASE.md" || fail 'Golden release docs missing performance policy evidence'
grep -Fq 'performance-doctor --certify' "$ROOT/docs/PERFORMANCE.md" || fail 'performance docs missing certification contract'

# Gaming is part of the canonical target and the runbook must not present it as
# an optional Golden pillar.
[[ "$GAMING_ENABLE" == true ]] || fail 'canonical config no longer enables Gaming'
grep -Fq 'profil Golden attend Gaming activé' "$ROOT/docs/RUNBOOK_PERSISTENT_DATA_GAMING.md" \
  || fail 'persistent-data/Gaming runbook does not state the canonical Gaming requirement'
grep -Fq 'GAMING_ENABLE="true"' "$ROOT/docs/GAMING.md" || fail 'Gaming guide missing canonical enablement'

# Runbooks may explain that bypasses are forbidden, but must never publish those
# bypasses as executable command lines.
for doc in docs/RUNBOOK_KVM.md docs/RUNBOOK_PERSISTENT_DATA_GAMING.md; do
  if grep -Eqi '^[[:space:]]*(sudo[[:space:]]+)?(setenforce[[:space:]]+0|systemctl[[:space:]]+(stop|disable)[[:space:]]+firewalld|chmod[[:space:]]+777)([[:space:]]|$)' "$ROOT/$doc"; then
    fail "$doc contains an executable forbidden troubleshooting bypass"
  fi
done

# Documentation portal must expose the role model and specialized runbooks.
for expected in DOCUMENTATION_MODEL.md RUNBOOK_KVM.md RUNBOOK_PERSISTENT_DATA_GAMING.md; do
  grep -Fq "$expected" "$ROOT/docs/README.md" || fail "docs/README.md missing $expected"
done
# Navigation destinations survive editorial regrouping and heading changes.
for target in INSTALLATION_GUIDE.md CONTROL_CENTER.md BACKUP_RESTORE.md TROUBLESHOOTING.md THREE_GATE_VALIDATION.md; do
  grep -Fq "]($target)" "$ROOT/docs/README.md" || fail "documentation portal missing journey: $target"
done

echo 'documentation/code alignment: PASS'

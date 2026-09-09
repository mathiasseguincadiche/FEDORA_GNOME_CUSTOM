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
# can be used to create or inspect the two Golden guests.
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
  grep -Fq "$UBUNTU_SERVER_NAME" "$ROOT/$doc" || fail "$doc missing Ubuntu domain name"
  grep -Fq "$UBUNTU_SERVER_RELEASE" "$ROOT/$doc" || fail "$doc missing Ubuntu release"
  grep -Fq "$WINDOWS11_NAME" "$ROOT/$doc" || fail "$doc missing Windows domain name"
  grep -Fq "vCPU               $UBUNTU_SERVER_VCPU" "$ROOT/$doc" || fail "$doc Ubuntu vCPU drift"
  grep -Fq 'RAM                16 Gio' "$ROOT/$doc" || fail "$doc Ubuntu RAM drift"
  grep -Fq "disque             $UBUNTU_SERVER_DISK_GB Gio qcow2" "$ROOT/$doc" || fail "$doc Ubuntu disk drift"
  grep -Fq "vCPU               $WINDOWS11_VCPU" "$ROOT/$doc" || fail "$doc Windows vCPU drift"
  grep -Fq 'RAM                12 Gio' "$ROOT/$doc" || fail "$doc Windows RAM drift"
  grep -Fq "disque             $WINDOWS11_DISK_GB Gio qcow2" "$ROOT/$doc" || fail "$doc Windows disk drift"
done

# Every executable Windows creation example must include both mandatory trusted
# publisher/source hashes. This catches drift in both direct-engine docs and the
# public Control Center documentation.
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
engine_docs = [
    root / "docs/KVM_QUICKSTART.md",
    root / "docs/VIRTUALIZATION.md",
    root / "docs/VM_PROFILES.md",
    root / "docs/RUNBOOK_KVM.md",
]
public_docs = [root / "docs/CONTROL_CENTER.md"]
errors = []

for path in engine_docs:
    text = path.read_text(encoding="utf-8")
    blocks = re.findall(r"```bash\n(.*?)```", text, flags=re.S)
    windows = [b for b in blocks if "create_windows11_vm.sh" in b]
    if not windows:
        errors.append(f"{path.name}: no executable direct Windows creation example")
        continue
    for block in windows:
        if "--windows-sha256" not in block or "--virtio-sha256" not in block:
            errors.append(f"{path.name}: direct Windows creation block omits mandatory trusted hashes")

for path in public_docs:
    text = path.read_text(encoding="utf-8")
    blocks = re.findall(r"```bash\n(.*?)```", text, flags=re.S)
    windows = [b for b in blocks if "control.sh kvm create-windows" in b]
    if not windows:
        errors.append(f"{path.name}: no public Windows creation example")
        continue
    for block in windows:
        if "--windows-sha256" not in block or "--virtio-sha256" not in block:
            errors.append(f"{path.name}: public Windows creation block omits mandatory trusted hashes")

if errors:
    for error in errors:
        print(error, file=sys.stderr)
    raise SystemExit(1)
PY

grep -Fq 'trusted SHA-256 is mandatory for both Windows and VirtIO media' "$ROOT/scripts/kvm/create_windows11_vm.sh" \
  || fail 'Windows creation script no longer exposes the mandatory-hash contract'
grep -Fq 'create_windows11_vm.sh` **exige**' "$ROOT/docs/SUPPLY_CHAIN.md" \
  || fail 'SUPPLY_CHAIN does not state that Windows/VirtIO hashes are mandatory'

if grep -Fq 'Création minimale' "$ROOT/docs/KVM_QUICKSTART.md"; then
  fail 'KVM_QUICKSTART still advertises an obsolete hashless Windows creation mode'
fi
if grep -Fq 'Lorsque ces valeurs sont fournies' "$ROOT/docs/SUPPLY_CHAIN.md"; then
  fail 'SUPPLY_CHAIN still describes mandatory Windows hashes as optional'
fi

# Public KVM creation routes must actually forward all remaining arguments to
# the hardened engines.
grep -Fq 'if [[ "${1:-}" == kvm ]]' "$ROOT/control.sh" || fail 'public KVM argument routing missing'
grep -Fq 'create_ubuntu_devops_vm.sh" "$@"' "$ROOT/control.sh" || fail 'Ubuntu public route does not forward arguments'
grep -Fq 'create_windows11_vm.sh" "$@"' "$ROOT/control.sh" || fail 'Windows public route does not forward arguments'

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
for heading in '# 1. Normes' '# 2. Installation' '# 3. Guides opérateur' '# 4. Références techniques' '# 5. Runbooks' '# 6. Certification, CI et gouvernance'; do
  grep -Fq "$heading" "$ROOT/docs/README.md" || fail "documentation portal missing role: $heading"
done

echo 'documentation/code alignment: PASS'

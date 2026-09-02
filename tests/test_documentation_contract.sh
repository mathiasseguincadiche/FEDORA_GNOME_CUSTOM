#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

require_file() {
  [[ -f "$ROOT/$1" ]] || { echo "missing required documentation file: $1" >&2; exit 1; }
}

for file in \
  docs/README.md \
  docs/CONTROL_CENTER.md \
  docs/GLOSSARY.md \
  docs/KVM_QUICKSTART.md \
  docs/KVM_NETWORK.md \
  docs/TROUBLESHOOTING.md \
  docs/VIRTUALIZATION.md \
  docs/VIRTUALBOX_GNOME_LAB.md \
  docs/EXECUTION_CONTRACT.md \
  docs/GNOME_INTEGRATION.md \
  docs/GNOME_PROFILE.md \
  docs/GNOME_EXTENSIONS.md \
  docs/CI_VALIDATION.md \
  docs/GTK4_APPLICATIONS.md \
  docs/SUPPLY_CHAIN.md; do
  require_file "$file"
done

# Control Center is the operator facade but must document the protected engines.
grep -Fq './control.sh' "$ROOT/README.md"
grep -Fq 'CONTROL_CENTER.md' "$ROOT/README.md"
grep -Fq './control.sh' "$ROOT/docs/README.md"
grep -Fq 'install.sh --apply' "$ROOT/docs/CONTROL_CENTER.md"
grep -Fq 'backup Restic' "$ROOT/docs/CONTROL_CENTER.md"
grep -Fq 'kernel-vanilla/stable' "$ROOT/docs/CONTROL_CENTER.md"
grep -Fq 'aucun flash' "$ROOT/docs/CONTROL_CENTER.md"

# Obsolete baseline commands must not return to user-facing documentation.
if grep -RInE --include='*.md' 'baseline-doctor[[:space:]]+(record-memory|record-nvme-io|record-suspend)' "$ROOT/docs" "$ROOT/README.md"; then
  echo 'obsolete baseline-doctor command found in documentation' >&2
  exit 1
fi

# GNOME docs must match the current four-extension functional contract.
for expected in 'Dash to Dock' 'AppIndicator' 'Desktop Icons NG' 'Show Desktop Plus'; do
  grep -Fq "$expected" "$ROOT/docs/GNOME_PROFILE.md" || { echo "GNOME_PROFILE missing functional extension: $expected" >&2; exit 1; }
  grep -Fq "$expected" "$ROOT/docs/GNOME_EXTENSIONS.md" || { echo "GNOME_EXTENSIONS missing functional extension: $expected" >&2; exit 1; }
done
grep -Fq 'exactement **quatre extensions fonctionnelles**' "$ROOT/docs/GNOME_PROFILE.md"
grep -Fq 'Bureau' "$ROOT/docs/GNOME_EXTENSIONS.md"
grep -Fq 'XDG Desktop' "$ROOT/docs/GNOME_EXTENSIONS.md"
grep -Fq 'Corbeille' "$ROOT/docs/GNOME_EXTENSIONS.md"
grep -Fq 'Super+D' "$ROOT/docs/GNOME_EXTENSIONS.md"
grep -Fq '74408' "$ROOT/docs/GNOME_EXTENSIONS.md"
grep -Fq '70326' "$ROOT/docs/GNOME_EXTENSIONS.md"
if grep -Fqi 'unique extension' "$ROOT/docs/GNOME_PROFILE.md"; then
  echo 'GNOME profile still claims a single functional extension' >&2
  exit 1
fi
if grep -Fqi 'Desktop Icons ne sont pas imposés' "$ROOT/docs/GNOME_EXTENSIONS.md"; then
  echo 'GNOME extensions documentation still excludes Desktop Icons despite DING being Golden' >&2
  exit 1
fi

# Fedora 44 does not expose DING through the project RPM manifest. Stale active
# claims would make the operator procedure factually wrong.
for file in README.md CHANGELOG.md docs/CI_VALIDATION.md docs/GNOME_INTEGRATION.md docs/GNOME_PROFILE.md docs/GNOME_EXTENSIONS.md; do
  if grep -Eqi 'DING.*(RPM Fedora|paquet Fedora|gnome-shell-extension-desktop-icons-ng)|RPM DING|paquet Fedora DING' "$ROOT/$file"; then
    echo "stale Fedora RPM DING claim found in documentation: $file" >&2
    exit 1
  fi
done
grep -Fq 'DING_SOURCE_URL="https://extensions.gnome.org/review/download/74408.shell-extension.zip"' "$ROOT/config/gnome.conf"
grep -Fq 'DING_VERSION="95"' "$ROOT/config/gnome.conf"

# GATE 2 must have a documented, isolated VirtualBox path while production
# APPLY remains bare-metal only.
grep -Fq 'VIRTUALBOX_GNOME_LAB.md' "$ROOT/docs/README.md"
grep -Fq 'scripts/lab/apply-gnome-virtualbox.sh --apply' "$ROOT/docs/VIRTUALBOX_GNOME_LAB.md"
grep -Fq 'install.sh --apply reste interdit' "$ROOT/docs/VIRTUALBOX_GNOME_LAB.md"
grep -Fq 'APPLY production' "$ROOT/docs/EXECUTION_CONTRACT.md"
grep -Fq 'LAB GNOME VirtualBox' "$ROOT/docs/EXECUTION_CONTRACT.md"
grep -Fq 'ne déverrouille jamais' "$ROOT/docs/README.md"
grep -Fq 'install.sh --apply' "$ROOT/docs/README.md"

# Professional catalog must reflect the real draw.io integration.
grep -Fq 'com.jgraph.drawio.desktop' "$ROOT/docs/GTK4_APPLICATIONS.md"

# Public governance docs must not describe limitations of a specific connector.
if grep -Fqi 'connexion GitHub utilisée' "$ROOT/docs/GITHUB_GOVERNANCE.md" || grep -Fqi 'connector' "$ROOT/docs/GITHUB_GOVERNANCE.md"; then
  echo 'tool-specific connector text leaked into public GitHub governance docs' >&2
  exit 1
fi

# KVM values documented for beginners must remain aligned with the versioned policy.
for expected in \
  'devops-nat' \
  'virbr50' \
  '192.168.50.0/24' \
  '192.168.50.254' \
  '192.168.50.100-200'; do
  grep -Fq "$expected" "$ROOT/docs/KVM_NETWORK.md" || { echo "KVM_NETWORK missing documented invariant: $expected" >&2; exit 1; }
done

grep -Fq 'KVM_NETWORK_NAME="devops-nat"' "$ROOT/config/virtualization.conf"
grep -Fq 'KVM_BRIDGE_NAME="virbr50"' "$ROOT/config/virtualization.conf"
grep -Fq 'KVM_NETWORK_CIDR="192.168.50.0/24"' "$ROOT/config/virtualization.conf"
grep -Fq 'KVM_GATEWAY="192.168.50.254"' "$ROOT/config/virtualization.conf"

grep -Fq "mode d'urgence" "$ROOT/docs/KVM_NETWORK.md"
grep -Fq 'guard_mode=normal' "$ROOT/docs/KVM_NETWORK.md"
grep -Fq 'SHA256SUMS.gpg' "$ROOT/docs/VIRTUALIZATION.md"
grep -Fq 'verify_ubuntu_cloud_image.sh' "$ROOT/docs/TROUBLESHOOTING.md"

# Troubleshooting must cover the main operational surfaces, not only graphics.
for expected in \
  'install.sh --apply' \
  'DNF' \
  'GNOME' \
  'Arc B580' \
  'devops-nat' \
  'guard_mode=emergency' \
  'cloud-init' \
  'Windows' \
  'Backup / Restore'; do
  grep -Fq "$expected" "$ROOT/docs/TROUBLESHOOTING.md" || { echo "troubleshooting missing scope: $expected" >&2; exit 1; }
done

# Normative docs use VERSION rather than stale release numbers in their titles/content.
for file in \
  docs/GOLDEN_WORKSTATION.md \
  docs/HARDWARE_BASELINE_CERTIFICATION.md \
  docs/HARDWARE_KVM_COMPLETION.md \
  docs/HARDWARE_STABILITY.md \
  docs/HOST_BASH_UX.md \
  docs/INDUSTRIAL_READINESS.md \
  docs/GNOME_INTEGRATION.md \
  docs/GNOME_PROFILE.md \
  docs/GNOME_EXTENSIONS.md \
  docs/VIRTUALBOX_GNOME_LAB.md \
  docs/DOCK_FAVORITES.md \
  docs/DESKTOP_LIFECYCLE.md \
  docs/UBUNTU_DEVOPS_READY.md; do
  if grep -Eq '0\.(8|9)(\.[0-9]+)?' "$ROOT/$file"; then
    echo "stale pre-0.10 release number found in normative doc: $file" >&2
    exit 1
  fi
done

# Check local Markdown links. External links and anchors are intentionally skipped.
python3 - "$ROOT" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1]).resolve()
files = [root / "README.md", *sorted((root / "docs").glob("*.md"))]
link_re = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
errors = []

for path in files:
    text = path.read_text(encoding="utf-8")
    for target in link_re.findall(text):
        target = target.strip().split("#", 1)[0]
        if not target or target.startswith(("http://", "https://", "mailto:")):
            continue
        resolved = (path.parent / target).resolve()
        try:
            resolved.relative_to(root)
        except ValueError:
            errors.append(f"{path.relative_to(root)} -> escapes repository: {target}")
            continue
        if not resolved.exists():
            errors.append(f"{path.relative_to(root)} -> missing: {target}")

if errors:
    print("broken local Markdown links:", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    raise SystemExit(1)
PY

echo 'documentation contract: PASS'

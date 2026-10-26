#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "github presentation contract: FAIL: $*" >&2; exit 1; }

for file in \
  README.md \
  LICENSE \
  CONTRIBUTING.md \
  docs/README.md \
  .github/ISSUE_TEMPLATE/bug_report.yml \
  .github/ISSUE_TEMPLATE/hardware_validation.yml \
  .github/ISSUE_TEMPLATE/documentation.yml \
  .github/ISSUE_TEMPLATE/feature_request.yml \
  .github/ISSUE_TEMPLATE/config.yml \
  lib/control_center_presentation.sh; do
  [[ -s "$ROOT/$file" ]] || fail "missing $file"
done

# Public repository licensing must remain explicit and machine-detectable.
grep -Fq 'Apache License' "$ROOT/LICENSE" || fail 'Apache-2.0 license title missing'
grep -Fq 'Version 2.0' "$ROOT/LICENSE" || fail 'Apache-2.0 version missing'

# Landing page: product, public entrypoint and discoverable procedures.
version="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[[ "$version" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]] || fail 'VERSION is not semantic x.y.z'
grep -Fq '# Fedora Golden Workstation' "$ROOT/README.md" || fail 'landing title missing'
grep -Fq 'actions/workflows/tests.yml/badge.svg?branch=main' "$ROOT/README.md" || fail 'Tests badge missing'
for target in LICENSE VERSION CONTRIBUTING.md docs/INSTALLATION_GUIDE.md docs/CONTROL_CENTER.md docs/BACKUP_RESTORE.md docs/GNOME.md docs/GAMING.md docs/KVM_QUICKSTART.md docs/TROUBLESHOOTING.md docs/README.md; do
  grep -Fq "]($target)" "$ROOT/README.md" || fail "landing navigation missing $target"
done
[[ -s "$ROOT/docs/assets/desktop-preview.svg" ]] || fail 'desktop preview missing'
grep -Fq 'docs/assets/desktop-preview.svg' "$ROOT/README.md" || fail 'README does not show the desktop preview'
grep -Fq 'Maquette illustrative, pas une capture réelle' "$ROOT/README.md" || fail 'README must label the preview as a mockup'
grep -Fq 'pas une capture réelle' "$ROOT/docs/assets/desktop-preview.svg" || fail 'preview image must label itself as a mockup'

# Validate the preparation path and status, without fixing editorial section names.
python3 - "$ROOT" <<'PY_LANDING'
from pathlib import Path
import json
import re
import sys
root = Path(sys.argv[1])
text = (root / 'README.md').read_text()
assert len(re.findall(r'^# ', text, re.M)) == 1, 'landing needs one page title'
assert 'Fedora 45' in text[:500] and 'GNOME 51' in text[:500], 'new-install target missing'
assert 'git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git' in text
blocks = re.findall(r'```bash\n(.*?)```', text, re.S)
commands = '\n'.join(blocks)
assert './control.sh status' in commands and './control.sh install dry-run' in commands
assert not re.search(r'^\s*(?:sudo\s+)?(?:./control.sh install apply|./install.sh --apply)', commands, re.M), 'landing must link to the full procedure before APPLY'
assert 'Gate 3' in text and 'ne certifie pas encore' in text, 'CI/physical distinction missing'
assert 'FEDORA45_PRIMARY.md' in text, 'qualification status must be discoverable'
if json.loads((root / 'profiles/fedora45/profile.json').read_text())['status'] == 'pending':
    assert 'pending' in text, 'pending profile advertised as production'
assert 'conçue et certifiée' not in text, 'unsupported physical-certification claim'
portal = (root / 'docs/README.md').read_text()
for target in ('INSTALLATION_GUIDE.md', 'CONTROL_CENTER.md', 'BACKUP_RESTORE.md', 'TROUBLESHOOTING.md', 'THREE_GATE_VALIDATION.md', 'DOCUMENTATION_MODEL.md'):
    assert f']({target})' in portal, f'missing user journey: {target}'
PY_LANDING

# Contribution and issue intake must preserve Golden invariants and avoid public secrets.
grep -Fq 'Ne pas affaiblir les garde-fous' "$ROOT/CONTRIBUTING.md" || fail 'contribution safeguards missing'
grep -Fq 'Un résultat CI ne constitue jamais une preuve physique.' "$ROOT/CONTRIBUTING.md" || fail 'CI/runtime distinction missing'
grep -Fq 'SECURITY.md' "$ROOT/CONTRIBUTING.md" || fail 'security reporting link missing'
grep -Fq 'blank_issues_enabled: false' "$ROOT/.github/ISSUE_TEMPLATE/config.yml" || fail 'blank issues policy missing'
grep -Fq 'Hardware / Gate 3 validation' "$ROOT/.github/ISSUE_TEMPLATE/hardware_validation.yml" || fail 'hardware template identity missing'
grep -Fq 'Documentation' "$ROOT/.github/ISSUE_TEMPLATE/documentation.yml" || fail 'documentation template missing'
grep -Fq 'Évolution / amélioration' "$ROOT/.github/ISSUE_TEMPLATE/feature_request.yml" || fail 'enhancement template missing'

# The terminal presentation layer is read-only UI and reflects the current Golden vocabulary.
grep -Fq 'Politique N / N-1 · max 2' "$ROOT/lib/control_center_presentation.sh" || fail 'current kernel presentation missing'
grep -Fq 'Data' "$ROOT/lib/control_center_presentation.sh" || fail 'data dashboard missing'
grep -Fq 'Gaming' "$ROOT/lib/control_center_presentation.sh" || fail 'gaming dashboard missing'
grep -Fq 'Performance' "$ROOT/lib/control_center_presentation.sh" || fail 'performance dashboard missing'
grep -Fq "cc_option 7 'Performance Fedora Linux'" "$ROOT/lib/control_center_presentation.sh" || fail 'performance main-menu pillar missing'
if grep -Eq 'dnf5?[[:space:]].*upgrade|borg[[:space:]]+(create|prune|compact|delete)|nft[[:space:]]+-f' "$ROOT/lib/control_center_presentation.sh"; then
  fail 'business logic must not leak into presentation layer'
fi

echo 'github presentation contract: PASS'

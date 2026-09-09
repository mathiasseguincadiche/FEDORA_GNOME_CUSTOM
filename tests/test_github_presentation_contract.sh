#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "github presentation contract: FAIL: $*" >&2; exit 1; }

for file in \
  README.md \
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

# Landing page: identity, live CI badges, quick start and honest project status.
grep -Fq '# Fedora 44 Golden Workstation' "$ROOT/README.md" || fail 'landing title missing'
grep -Fq '**Golden Workstation 0.14.0**' "$ROOT/README.md" || fail 'version identity missing'
grep -Fq 'actions/workflows/tests.yml/badge.svg?branch=main' "$ROOT/README.md" || fail 'Tests badge missing'
grep -Fq 'actions/workflows/shell-quality.yml/badge.svg?branch=main' "$ROOT/README.md" || fail 'Shell quality badge missing'
grep -Fq 'actions/workflows/fedora-package-preflight.yml/badge.svg?branch=main' "$ROOT/README.md" || fail 'Fedora package badge missing'
grep -Fq 'actions/workflows/fedora-gaming-pretest.yml/badge.svg?branch=main' "$ROOT/README.md" || fail 'Gaming badge missing'
grep -Fq 'État logiciel : CODE-READY' "$ROOT/README.md" || fail 'honest code-ready status missing'
grep -Fq 'Certification matérielle : Gate 3 bare-metal à exécuter' "$ROOT/README.md" || fail 'bare-metal status missing'
if grep -Fq 'conçue et certifiée' "$ROOT/README.md"; then
  fail 'README must not claim physical certification before Gate 3'
fi

# Quick start must be the public entrypoint, not internal engines.
grep -Fq 'git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git' "$ROOT/README.md" || fail 'clone quick start missing'
grep -Fq './control.sh' "$ROOT/README.md" || fail 'Control Center quick start missing'
grep -Fq './control.sh doctor gaming' "$ROOT/README.md" || fail 'Gaming operator route missing'
grep -Fq '/data/Jeux' "$ROOT/README.md" || fail 'persistent Games storage missing'
grep -Fq 'CONTRIBUTING.md' "$ROOT/README.md" || fail 'contribution guide link missing'
grep -Fq 'docs/GOLDEN_RELEASE.md' "$ROOT/README.md" || fail 'Golden release documentation missing'
grep -Fq 'THREE_GATE_VALIDATION.md' "$ROOT/README.md" || fail 'three-gate documentation missing'

# The README must explain the product before the certification pipeline.
python3 - "$ROOT/README.md" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text(encoding='utf-8')
quick = text.index('## Démarrage rapide')
architecture = text.index('## Architecture globale')
validation = text.index('# Validation complète')
assert quick < architecture < validation, 'README ordering must be quick start → architecture → validation'
assert text.index('## Gaming') < validation, 'Gaming must be presented before validation'
assert text.index('## Virtualisation') < validation, 'KVM must be presented before validation'
assert text.index('## Sauvegarde et restauration') < validation, 'backup must be presented before validation'
assert 'Gate 3 est la certification de la vraie machine après installation/APPLY' in text
PY

# Documentation portal must also keep runtime certification at the end of the journey.
grep -Fq '# Validation officielle' "$ROOT/docs/README.md" || fail 'docs validation section missing'
grep -Fq 'Installation Fedora 44 bare-metal' "$ROOT/docs/README.md" || fail 'bare-metal placement missing in docs portal'
grep -Fq "ne déverrouille jamais \`install.sh --apply\`" "$ROOT/docs/README.md" || fail 'VirtualBox safety statement missing'

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
if grep -Eq 'dnf5?[[:space:]].*upgrade|restic[[:space:]]+backup|nft[[:space:]]+-f' "$ROOT/lib/control_center_presentation.sh"; then
  fail 'business logic must not leak into presentation layer'
fi

echo 'github presentation contract: PASS'

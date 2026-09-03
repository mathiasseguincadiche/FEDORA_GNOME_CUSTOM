#!/usr/bin/env bash
# Test harnesses below intentionally isolate mock environment mutations in
# subshells and define functions invoked indirectly by sourced orchestrator code.
# shellcheck disable=SC2030,SC2031,SC2317
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

[[ "$(tr -d '[:space:]' < "$ROOT/VERSION")" == 0.14.0 ]]
grep -Fq '**Golden Workstation 0.14.0**' "$ROOT/README.md"
grep -Fq '## 0.14.0 — 2026-09-03' "$ROOT/CHANGELOG.md"

# User-decided HOST policy.
grep -Fq 'services --enabled=NetworkManager,firewalld --disabled=sshd' "$ROOT/installer/generate-fedora44-kickstart.sh"
grep -Fq 'openssh-clients' "$ROOT/installer/generate-fedora44-kickstart.sh"
if grep -Eqi 'autopart[^\n]*--encrypted|luks' "$ROOT/installer/generate-fedora44-kickstart.sh"; then
  echo 'Kickstart must not silently introduce LUKS into the chosen Golden policy' >&2
  exit 1
fi
grep -Fxq 'mode=candidate-certified' "$ROOT/config/kernel-lifecycle.policy"
grep -Fxq 'keep_previous_certified=true' "$ROOT/config/kernel-lifecycle.policy"
grep -Fq 'KERNEL_REQUIRE_LATEST_STABLE="false"' "$ROOT/config/kernel.conf"
grep -Fq 'KERNEL_KEEP_FEDORA_FALLBACK="true"' "$ROOT/config/kernel.conf"
grep -Fq 'KERNEL_BLOCK_SECURE_BOOT="true"' "$ROOT/config/kernel.conf"
grep -Fq 'diagnostics/final-certification" certify' "$ROOT/lib/kernel_lifecycle.sh"

# Config is schema-validated before sourcing and remains declarative.
[[ -r "$ROOT/config/schema.digest" ]]
[[ -r "$ROOT/config/schema-enums.tsv" ]]
grep -Fq 'validate-config.sh' "$ROOT/lib/config.sh"
bash "$ROOT/scripts/config/validate-config.sh" "$ROOT/config" >/dev/null
python3 - "$ROOT/config" <<'PY'
from pathlib import Path
import re
import sys
root = Path(sys.argv[1])
assignment = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*=.*$')
for path in sorted(root.glob('*.conf')):
    for lineno, raw in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        if not assignment.match(line):
            raise SystemExit(f'{path}:{lineno}: non-declarative config line: {raw}')
        for forbidden in ('$(', '`', '<(', '>(', '&&', '||', ';'):
            if forbidden in line:
                raise SystemExit(f'{path}:{lineno}: executable shell syntax forbidden in config: {forbidden}')
PY

# Mutating commands must not execute at module source time.
python3 - "$ROOT/modules" <<'PY'
from pathlib import import Path
PY

#!/usr/bin/env bash
# shellcheck disable=SC2016
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
helper="$ROOT/scripts/ci/enable-rpmfusion.sh"

[[ -s "$helper" ]] || { echo 'RPM Fusion CI bootstrap helper missing' >&2; exit 1; }
bash -n "$helper"

grep -Fq 'RPMFUSION_FEDORA_RELEASE:-44' "$helper"
grep -Fq 'RPMFUSION_BOOTSTRAP_ATTEMPTS:-3' "$helper"
grep -Fq 'https://mirrors.rpmfusion.org/${channel}/fedora/${filename}' "$helper"
grep -Fq 'https://download1.rpmfusion.org/${channel}/fedora/${filename}' "$helper"
grep -Fq 'timeout 90 dnf -y install "$url"' "$helper"
grep -Fq 'for ((attempt = 1; attempt <= attempts; attempt++)); do' "$helper"
grep -Fq 'for url in "${endpoints[@]}"; do' "$helper"
grep -Fq 'rpmfusion-free-release' "$helper"
grep -Fq 'rpmfusion-nonfree-release' "$helper"
grep -Fq 'all official bootstrap endpoints failed' "$helper"

for workflow in \
  .github/workflows/fedora-gaming-pretest.yml \
  .github/workflows/fedora-host-pretest.yml \
  .github/workflows/fedora-package-preflight.yml; do
  grep -Fq 'bash scripts/ci/enable-rpmfusion.sh' "$ROOT/$workflow" || {
    echo "$workflow does not use the shared RPM Fusion bootstrap" >&2
    exit 1
  }
  if grep -Eq 'mirrors[.]rpmfusion[.]org|download1[.]rpmfusion[.]org' "$ROOT/$workflow"; then
    echo "$workflow bypasses the shared RPM Fusion bootstrap" >&2
    exit 1
  fi
done

grep -Fq 'download1.rpmfusion.org' "$ROOT/docs/CI_VALIDATION.md" || {
  echo 'CI documentation does not describe the RPM Fusion fallback' >&2
  exit 1
}

echo 'RPM Fusion CI bootstrap contract: PASS'

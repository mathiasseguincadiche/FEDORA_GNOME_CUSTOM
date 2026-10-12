#!/usr/bin/env bash
# Fedora CI-only Flathub bootstrap. Use the official CDN, keep GPG verification,
# and fail closed after bounded retries (network failures are not a PASS).
set -Eeuo pipefail
if (($#)); then echo 'Usage: bash scripts/ci/ensure-flathub.sh' >&2; exit 2; fi
command -v flatpak >/dev/null 2>&1 || { echo 'flatpak missing' >&2; exit 1; }
url='https://dl.flathub.org/repo/flathub.flatpakrepo'
for attempt in 1 2 3 4; do
  if flatpak remote-add --if-not-exists --system flathub "$url"; then
    if flatpak remotes --system --columns=name | grep -Fxq flathub; then
      echo "Flathub system remote available (official CDN, attempt $attempt)"
      exit 0
    fi
  fi
  if (( attempt < 4 )); then
    echo "::warning::Flathub bootstrap failed ($attempt/4); retrying the official CDN" >&2
    sleep $((attempt * 5))
  fi
done
echo 'ERROR: Flathub official CDN inaccessible after four attempts; preflight fails closed' >&2
exit 1

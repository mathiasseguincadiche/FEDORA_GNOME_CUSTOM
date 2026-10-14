#!/usr/bin/env bash
# Fedora 45 signed-media verification entrypoint. Never fall back to Fedora 44.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${1:-}" == --release ]]; then
  [[ "${2:-}" == 45 ]] || { echo 'This entrypoint targets Fedora 45 only; use the historical verifier for Fedora 44.' >&2; exit 2; }
  shift 2
fi
exec bash "$root/installer/verify-fedora44-media.sh" --release 45 "$@"

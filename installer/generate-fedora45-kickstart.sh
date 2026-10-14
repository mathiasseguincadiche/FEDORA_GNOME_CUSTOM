#!/usr/bin/env bash
# Fedora 45 fresh-install entrypoint. The existing fail-closed media/profile validator
# runs BEFORE disk discovery, confirmation or Kickstart generation.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ "${1:-}" == --release ]]; then
  [[ "${2:-}" == 45 ]] || { echo 'This entrypoint targets Fedora 45 only; Fedora 44 is historical.' >&2; exit 2; }
  shift 2
fi
exec bash "$root/installer/generate-fedora44-kickstart.sh" --release 45 "$@"

#!/usr/bin/env bash
# Explicit historical adapter: Fedora 44.
set -Eeuo pipefail
if [[ "${1:-}" == --release ]]; then
  [[ "${2:-}" == 44 ]] || { echo 'This entrypoint targets Fedora 44 only.' >&2; exit 2; }
  shift 2
fi
exec bash "$(dirname "${BASH_SOURCE[0]}")/lib/verify-media.sh" --release 44 "$@"

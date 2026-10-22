#!/usr/bin/env bash
# Primary fresh-install target: Fedora 45.
set -Eeuo pipefail
if [[ "${1:-}" == --release ]]; then
  [[ "${2:-}" == 45 ]] || { echo 'This entrypoint targets Fedora 45 only.' >&2; exit 2; }
  shift 2
fi
exec bash "$(dirname "${BASH_SOURCE[0]}")/lib/generate-kickstart.sh" --release 45 "$@"

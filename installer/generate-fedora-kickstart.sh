#!/usr/bin/env bash
# Fresh-install default: Fedora 45. The selected release remains blocked while pending.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$root/installer/generate-fedora45-kickstart.sh" "$@"

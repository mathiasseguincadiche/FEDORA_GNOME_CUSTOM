#!/usr/bin/env bash
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$root/installer/generate-fedora44-kickstart.sh" "$@"

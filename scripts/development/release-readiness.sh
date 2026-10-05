#!/usr/bin/env bash
# Read-only downloaded-artifact and real Fedora 45 package readiness.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec python3 "$root/scripts/development/release-readiness.py" "$@"

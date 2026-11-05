#!/usr/bin/env bash
# Compatibility alias: same interface as ./control.sh.
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$REPO_ROOT/control.sh" "$@"

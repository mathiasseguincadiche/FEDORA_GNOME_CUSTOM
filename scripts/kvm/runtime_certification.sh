#!/usr/bin/env bash
# Stable entrypoint for scripts/kvm/runtime_certification_core.sh.
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec "$REPO_ROOT/scripts/kvm/runtime_certification_core.sh" "$@"

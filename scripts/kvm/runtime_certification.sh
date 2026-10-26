#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
core="$REPO_ROOT/scripts/kvm/runtime_certification_core.sh"
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
if ! "$core" >"$tmp" 2>&1; then cat "$tmp"; exit 1; fi
# The core owns host/Rocky/network/XML checks. The Windows doctor checks QGA now
# and reads the last recorded installation check, replacing the core's advisory.
grep -v -E '^WARN[[:space:]]+Windows guest integration' "$tmp" || true
"$REPO_ROOT/diagnostics/windows-guest-doctor"
printf '\nRuntime certification: Windows QGA available + recorded installation check PASS\n'

#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
core="$REPO_ROOT/scripts/kvm/runtime_certification_core.sh"
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
if ! "$core" >"$tmp" 2>&1; then cat "$tmp"; exit 1; fi
# The core owns host/Ubuntu/network/XML checks. Windows live health is now a strict
# QGA-retrieved contract, so suppress the obsolete advisory line from the core.
grep -v -E '^WARN[[:space:]]+Windows guest integration' "$tmp" || true
"$REPO_ROOT/diagnostics/windows-guest-doctor"
printf '\nRuntime certification: Windows live guest contract PASS\n'

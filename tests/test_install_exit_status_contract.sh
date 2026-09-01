#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
install="$ROOT/install.sh"

[[ -f "$install" ]] || { echo 'missing install.sh' >&2; exit 1; }

# A failed orchestrator run must preserve its real non-zero status. In Bash,
# capturing $? after a completed `if ... fi` without an else can yield 0 and
# turn a failed preflight into `PREFLIGHT FAIL rc=0` / process exit 0.
grep -Fq 'else' "$install"
grep -Fq 'rc=$?' "$install"
grep -Fq 'PREFLIGHT FAIL rc=$rc' "$install"
grep -Fq 'exit "$rc"' "$install"

if grep -Eq '^[[:space:]]*fi[[:space:]]*$' "$install" && grep -Fq 'rc=$?; report=' "$install"; then
  echo 'install.sh must capture orchestrator status inside the failure branch, not after fi' >&2
  exit 1
fi

echo 'install exit-status contract: PASS'

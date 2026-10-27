#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
install="$ROOT/install.sh"
dollar='$'

[[ -f "$install" ]] || { echo 'missing install.sh' >&2; exit 1; }

# A failed orchestrator run must preserve its real non-zero status. In Bash,
# capturing the status after a completed `if ... fi` without an else can yield
# 0 and turn a failed preflight into `PREFLIGHT FAIL rc=0` / process exit 0.
grep -Fq 'else' "$install"
grep -Fq "rc=${dollar}?" "$install"
grep -Fq "PREFLIGHT FAIL rc=${dollar}rc" "$install"
grep -Fq "exit \"${dollar}rc\"" "$install"

if grep -Fq "rc=${dollar}?; report=" "$install"; then
  echo 'install.sh must capture orchestrator status inside the failure branch, not after fi' >&2
  exit 1
fi

echo 'install exit-status contract: PASS'

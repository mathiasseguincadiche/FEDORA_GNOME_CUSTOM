#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cat <<EOF
Repair is diagnosis-first and intentionally does not apply blind kernel/GPU tweaks.

1. $REPO_ROOT/diagnostic.sh
2. $REPO_ROOT/diagnostics/graphics-doctor
3. $REPO_ROOT/diagnostics/suspend-doctor
4. $REPO_ROOT/scripts/collect-boot-failure.sh

After identifying a failing module, rerun a full same-commit dry-run before APPLY.
EOF

#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
# shellcheck source=lib/control_center.sh
source "$REPO_ROOT/lib/control_center.sh"

control_center_main "$@"

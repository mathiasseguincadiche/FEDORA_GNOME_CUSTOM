#!/usr/bin/env bash
# Installs the pinned Tiling Assistant extension (see install-pinned-extension.sh).
set -Eeuo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/install-pinned-extension.sh" TILING_ASSISTANT "$@"

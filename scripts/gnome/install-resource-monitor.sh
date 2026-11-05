#!/usr/bin/env bash
# Installs the pinned top-bar resource monitor extension (see install-pinned-extension.sh).
set -Eeuo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/install-pinned-extension.sh" RESOURCE_MONITOR "$@"

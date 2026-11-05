#!/usr/bin/env bash
# Installs the pinned Show Desktop extension (see install-pinned-extension.sh).
set -Eeuo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/install-pinned-extension.sh" SHOW_DESKTOP_PLUS "$@"

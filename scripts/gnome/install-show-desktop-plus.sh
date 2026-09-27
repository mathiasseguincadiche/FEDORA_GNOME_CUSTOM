#!/usr/bin/env bash
set -Eeuo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/install-pinned-extension.sh" SHOW_DESKTOP_PLUS "$@"

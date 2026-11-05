#!/usr/bin/env bash
# Installs the pinned Gtk4 DING desktop-icons extension (see install-pinned-extension.sh).
set -Eeuo pipefail
exec bash "$(dirname "${BASH_SOURCE[0]}")/install-pinned-extension.sh" DING "$@"

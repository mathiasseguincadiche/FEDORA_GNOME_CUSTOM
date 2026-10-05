#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/validation_gates.sh"

ui_banner 'THREE-GATE VALIDATION' 'CURRENT SOURCE / IMPORTED PROOF STATUS'
validation_pipeline_status
printf '\nExpected sequence:\n'
printf '  Gate 1  selected Fedora release / WSL2      system + logic, physical hardware DEFERRED\n'
printf '  Gate 2  selected Fedora release / VirtualBox GNOME desktop + manual visual sign-off\n'
printf '  Gate 3  selected Fedora release / bare-metal complete Golden hardware/software certification\n'

#!/usr/bin/env bash
set -Eeuo pipefail

gaming_validation_enabled() { is_true "${GAMING_ENABLE:-false}"; }

gaming_validation_precheck() { return 0; }

gaming_validation_plan() {
  if gaming_validation_enabled; then
    echo 'Validate the installed gaming payload; physical Arc B580, Vulkan renderer, Wayland and 1440p/240 Hz evidence remain bare-metal-only.'
  else
    echo 'Gaming validation skipped because the optional profile is disabled.'
  fi
}

gaming_validation_apply() { return 0; }

gaming_validation_postcheck() {
  gaming_validation_enabled || return 0
  is_true "${DRY_RUN:-true}" && return 0
  "$REPO_ROOT/diagnostics/gaming-doctor" --quiet
}

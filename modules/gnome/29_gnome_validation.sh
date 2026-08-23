#!/usr/bin/env bash
set -Eeuo pipefail
gnome_validation_precheck() { :; }
gnome_validation_plan() { echo 'Validate GNOME/Nautilus/portal stack and current Wayland session when running inside GNOME.'; }
gnome_validation_apply() { :; }
gnome_validation_postcheck() { is_true "${DRY_RUN:-true}" && return 0; "$REPO_ROOT/diagnostics/gnome-doctor" --quiet; }

#!/usr/bin/env bash
set -Eeuo pipefail
hardware_validation_precheck() { :; }
hardware_validation_plan() { echo 'Run read-only hardware doctors after convergence.'; }
hardware_validation_apply() { :; }
hardware_validation_postcheck() { is_true "${DRY_RUN:-true}" && return 0; "$REPO_ROOT/diagnostics/graphics-doctor" --quiet && "$REPO_ROOT/diagnostics/storage-doctor" --quiet; }

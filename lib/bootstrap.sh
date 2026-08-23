#!/usr/bin/env bash

engine_bootstrap() {
  # shellcheck source=lib/constants.sh
  source "$REPO_ROOT/lib/constants.sh"
  source "$REPO_ROOT/lib/common.sh"
  source "$REPO_ROOT/lib/logging.sh"
  source "$REPO_ROOT/lib/ui.sh"
  source "$REPO_ROOT/lib/config.sh"
  source "$REPO_ROOT/lib/mutations.sh"
  source "$REPO_ROOT/lib/module_catalog.sh"
  source "$REPO_ROOT/lib/orchestrator.sh"
  source "$REPO_ROOT/lib/apply_gate.sh"
  logging_init
  config_load
}

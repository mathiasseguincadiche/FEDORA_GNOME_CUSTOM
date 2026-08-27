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
  source "$REPO_ROOT/lib/baseline.sh"
  source "$REPO_ROOT/lib/apply_gate.sh"
  logging_init
  config_load

  # Runtime identity is detected after local configuration is loaded so a
  # machine-local file cannot spoof a privileged bare-metal environment.
  RUNTIME_ENVIRONMENT="$(runtime_environment_detect)"
  export RUNTIME_ENVIRONMENT
}

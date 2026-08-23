#!/usr/bin/env bash

config_load() {
  local file local_override="$REPO_ROOT/config/local.conf"

  for file in "$REPO_ROOT"/config/*.conf; do
    [[ -r "$file" ]] || continue
    [[ "$file" == "$local_override" ]] && continue
    # shellcheck disable=SC1090
    source "$file"
  done

  if [[ -r "$local_override" ]]; then
    # Local machine-specific values must always win over versioned defaults.
    # shellcheck disable=SC1090
    source "$local_override"
  fi
}

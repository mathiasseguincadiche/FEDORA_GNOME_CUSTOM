#!/usr/bin/env bash

config_load() {
  local file
  for file in "$REPO_ROOT"/config/*.conf; do
    [[ -r "$file" ]] || continue
    # shellcheck disable=SC1090
    source "$file"
  done
}

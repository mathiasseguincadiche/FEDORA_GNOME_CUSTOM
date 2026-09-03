#!/usr/bin/env bash
# REPO_ROOT is intentionally injected by repository entrypoints before this library is sourced.
# shellcheck disable=SC2153

config_load() {
  local f local_override="$REPO_ROOT/config/local.conf"
  local validator="$REPO_ROOT/scripts/config/validate-config.sh"

  [[ -x "$validator" || -r "$validator" ]] || {
    echo "Missing config validator: $validator" >&2
    return 60
  }

  # Validate canonical configuration and local overrides before sourcing any
  # configuration as shell. Keep normal bootstrap output clean; validation
  # failures remain actionable on stderr.
  bash "$validator" "$REPO_ROOT/config" >/dev/null || return $?

  for f in "$REPO_ROOT"/config/*.conf; do
    [[ -r "$f" ]] || continue
    [[ "$f" == "$local_override" ]] && continue
    # shellcheck disable=SC1090
    source "$f"
  done

  if [[ -r "$local_override" ]]; then
    # Local machine-specific values must always win over versioned defaults.
    # shellcheck disable=SC1090
    source "$local_override"
  fi
}

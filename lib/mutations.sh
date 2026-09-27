#!/usr/bin/env bash

run_readonly() {
  local scope="$1"; shift
  log_info "$scope" "READ: $*"
  "$@"
}

run_mutating() {
  local scope="$1"; shift
  if is_true "${DRY_RUN:-true}"; then
    log_info "$scope" "PREFLIGHT SKIP MUTATION: $*"
    return 0
  fi
  log_info "$scope" "APPLY: $*"
  "$@"
}

install_manifest_packages() {
  local scope="$1" manifest="$2"
  local -a packages=()
  local payload rc
  [[ -f "$manifest" && -r "$manifest" ]] || {
    log_error "$scope" "Package manifest is missing/unreadable: $manifest"
    return "${EXIT_CONFIG_FAILED:-60}"
  }
  if payload="$(grep -Ev '^[[:space:]]*(#|$)' "$manifest")"; then
    mapfile -t packages <<< "$payload"
  else
    rc=$?
    # grep rc=1 means a deliberately empty manifest, rc>1 is an I/O error.
    (( rc == 1 )) || return "${EXIT_CONFIG_FAILED:-60}"
  fi
  ((${#packages[@]} > 0)) || return 0
  run_mutating "$scope" sudo dnf -y install "${packages[@]}"
}

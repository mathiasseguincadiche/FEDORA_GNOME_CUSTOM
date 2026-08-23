#!/usr/bin/env bash

run_readonly() {
  local scope="$1"; shift
  log_info "$scope" "READ: $*"
  "$@"
}

run_mutating() {
  local scope="$1"; shift
  if is_true "${DRY_RUN:-true}"; then
    log_info "$scope" "DRY-RUN MUTATION: $*"
    return 0
  fi
  log_info "$scope" "APPLY: $*"
  "$@"
}

install_manifest_packages() {
  local scope="$1" manifest="$2"
  local -a packages=()
  mapfile -t packages < <(grep -Ev '^[[:space:]]*(#|$)' "$manifest")
  ((${#packages[@]} > 0)) || return 0
  run_mutating "$scope" sudo dnf -y install "${packages[@]}"
}

#!/usr/bin/env bash
# shellcheck disable=SC2153
# Internal runner. Never call phase functions from an if/|| condition here.
set -Eeuo pipefail
shopt -s inherit_errexit
path="$1"; prefix="$2"; status_file="$3"; id="$4"; scope="$5"
phase=bootstrap
detail=
finish() {
  local rc=$?
  trap - EXIT
  if (( rc == 0 )) && [[ "$phase" != complete ]]; then rc=60; detail="premature successful exit"; fi
  if (( rc == 0 )); then
    printf 'OK|complete|0|complete\n' > "$status_file"
  else
    printf 'KO|%s|%s|%s\n' "$phase" "$rc" "${detail:-$phase rc=$rc}" > "$status_file"
  fi
  exit "$rc"
}
trap finish EXIT
source "$REPO_ROOT/lib/bootstrap.sh"
engine_load_libraries
config_load
phase=source
source "$path"
phase=contract
for step in precheck plan apply postcheck; do
  declare -F "${prefix}_${step}" >/dev/null || { detail="contract missing ${prefix}_${step}"; exit "$EXIT_CONFIG_FAILED"; }
done
ui_check INFO "$id" "$scope"
phase=precheck
"${prefix}_precheck"
for phase in plan apply postcheck; do
  "${prefix}_${phase}" >> "$MODULE_LOG" 2>&1
done
phase=complete

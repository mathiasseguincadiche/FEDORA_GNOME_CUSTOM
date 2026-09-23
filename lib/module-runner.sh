#!/usr/bin/env bash
# Internal process boundary; never invoke module phase functions conditionally.
set -Eeuo pipefail
shopt -s inherit_errexit
REPO_ROOT="$1"
module_path="$2"
prefix="$3"
module_id="$4"
module_scope="$5"
status_file="$6"
requested_dry_run="$7"
phase=bootstrap
record_failure() {
  local rc="$1"
  printf 'KO|%s|%s|%s rc=%s\n' "$phase" "$rc" "$phase" "$rc" > "$status_file"
  exit "$rc"
}
trap 'record_failure "$?"' ERR
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
DRY_RUN="$requested_dry_run"; export DRY_RUN
phase=source
source "$module_path"
phase=contract
for phase_name in precheck plan apply postcheck; do
  declare -F "${prefix}_${phase_name}" >/dev/null || {
    printf 'KO|contract|%s|contract missing %s\n' "${EXIT_CONFIG_FAILED:-60}" "${prefix}_${phase_name}" > "$status_file"
    exit "${EXIT_CONFIG_FAILED:-60}"
  }
done
ui_check INFO "$module_id" "$module_scope"
for phase in precheck plan apply postcheck; do
  "${prefix}_${phase}" >> "$MODULE_LOG" 2>&1
done
printf 'OK|complete|0|complete\n' > "$status_file"

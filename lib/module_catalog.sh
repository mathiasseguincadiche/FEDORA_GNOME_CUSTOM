#!/usr/bin/env bash

declare -ag CATALOG_IDS=()
declare -Ag CATALOG_SCOPE=() CATALOG_DEPS=() CATALOG_PATH=()

module_catalog_load() {
  local file="$1" id scope deps path
  CATALOG_IDS=()
  while IFS='|' read -r id scope deps path; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    CATALOG_IDS+=("$id")
    CATALOG_SCOPE["$id"]="$scope"
    CATALOG_DEPS["$id"]="$deps"
    CATALOG_PATH["$id"]="$path"
  done < "$file"
}

module_catalog_validate() {
  local id dep
  declare -A seen=()
  for id in "${CATALOG_IDS[@]}"; do
    [[ -r "$REPO_ROOT/${CATALOG_PATH[$id]}" ]] || { log_error ENGINE "missing module: ${CATALOG_PATH[$id]}"; return "$EXIT_CONFIG_FAILED"; }
    for dep in ${CATALOG_DEPS[$id]}; do
      [[ -n "${seen[$dep]:-}" ]] || { log_error ENGINE "dependency $dep must appear before $id"; return "$EXIT_CONFIG_FAILED"; }
    done
    seen["$id"]=1
  done
}

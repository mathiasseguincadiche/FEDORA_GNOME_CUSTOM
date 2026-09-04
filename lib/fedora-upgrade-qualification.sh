#!/usr/bin/env bash

# Pure Fedora N+1 qualification helpers shared by the host lifecycle and CI.
# repoclosure exit code 1 is a normal qualification finding when it is paired
# with a valid non-empty JSON result. Tool/parser failures remain fatal.

fedora_upgrade_classify_repoclosure() {
  local rc="$1" json="$2" count
  [[ "$rc" =~ ^[0-9]+$ ]] || return 2
  command -v jq >/dev/null 2>&1 || return 2
  jq -e 'type == "array"' "$json" >/dev/null 2>&1 || return 2
  count="$(jq 'length' "$json")" || return 2

  case "$rc" in
    0)
      (( count == 0 )) || return 2
      printf 'CLEAR\n'
      ;;
    1)
      (( count > 0 )) || return 2
      printf 'BLOCKED\n'
      ;;
    *)
      return 2
      ;;
  esac
}

fedora_upgrade_repoclosure_probe() {
  local target="$1" json="$2" err="$3" status="$4" rc classification
  command -v dnf5 >/dev/null 2>&1 || return 2
  command -v jq >/dev/null 2>&1 || return 2

  if dnf5 --releasever="$target" repoclosure --json >"$json" 2>"$err"; then
    rc=0
  else
    rc=$?
  fi

  if ! classification="$(fedora_upgrade_classify_repoclosure "$rc" "$json")"; then
    return 2
  fi
  printf '%s\n' "$classification" >"$status"
}

#!/usr/bin/env bash

is_true() {
  case "${1,,}" in true|1|yes|on) return 0 ;; *) return 1 ;; esac
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

normalize_hex() {
  local value="${1,,}"
  printf '%s\n' "${value#0x}"
}

trim() {
  local value="$*"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

repo_commit() {
  git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || printf 'unknown\n'
}

#!/usr/bin/env bash
# An exclusion assertion must fail on a match AND on an unreadable input.
set -Eeuo pipefail
if (( $# == 0 )); then
  echo 'Usage: assert-absent.sh COMMAND [ARG...]' >&2
  exit 2
fi
if "$@"; then
  printf 'CI exclusion assertion failed: %s\n' "$*" >&2
  exit 1
else
  rc=$?
  if (( rc != 1 )); then
    printf 'CI exclusion could not be checked (rc=%s): %s\n' "$rc" "$*" >&2
    exit "$rc"
  fi
fi

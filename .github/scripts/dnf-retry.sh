#!/usr/bin/env bash
# Reuse downloaded packages after transient mirror failures. Never turn a
# failed package transaction into a successful laboratory qualification.
set -Eeuo pipefail
(($# > 0)) || exit 2
rc=1
for attempt in 1 2 3; do
  if "$@"; then exit 0; else rc=$?; fi
  if (( attempt < 3 )); then
    printf 'Package command failed (rc=%s, attempt %s/3); retrying unchanged in 10 seconds.\n' "$rc" "$attempt" >&2
    sleep 10
  fi
done
exit "$rc"

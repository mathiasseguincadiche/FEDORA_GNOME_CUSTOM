#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
while IFS='|' read -r id scope _deps path; do
  [[ -z "$id" || "$id" == \#* ]] && continue
  [[ -n "$scope" && -r "$ROOT/$path" ]] || { echo "invalid module entry: $id $path" >&2; exit 1; }
done < "$ROOT/manifests/module-plan.conf"
while IFS= read -r file; do bash -n "$ROOT/$file"; done < <(git -C "$ROOT" ls-files '*.sh')
echo 'structure: PASS'

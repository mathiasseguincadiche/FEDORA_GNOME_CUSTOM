#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
while IFS='|' read -r id scope deps path; do
  [[ -z "$id" || "$id" == \#* ]] && continue
  [[ -n "$scope" && -r "$ROOT/$path" ]] || { echo "invalid module entry: $id $path" >&2; exit 1; }
done < "$ROOT/manifests/module-plan.conf"
for f in "$ROOT"/*.sh "$ROOT"/diagnostics/* "$ROOT"/scripts/*.sh "$ROOT"/scripts/systemd/* "$ROOT"/modules/*/*.sh; do bash -n "$f"; done
echo 'structure: PASS'

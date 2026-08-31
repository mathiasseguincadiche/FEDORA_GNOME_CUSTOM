#!/usr/bin/env bash
set -Eeuo pipefail
repo="${1:-mathiasseguincadiche/FEDORA_GNOME_CUSTOM}"
api="https://api.github.com/repos/${repo}/branches/main"
command -v curl >/dev/null || { echo 'curl required' >&2; exit 2; }
command -v jq >/dev/null || { echo 'jq required' >&2; exit 2; }
payload="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$api")"
if jq -e '.protected == true' <<<"$payload" >/dev/null; then
  echo 'OK: main is protected.'
  exit 0
fi
echo 'KO: main is not protected. Apply the repository ruleset described in docs/GITHUB_GOVERNANCE.md.' >&2
exit 1

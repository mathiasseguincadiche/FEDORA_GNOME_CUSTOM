#!/usr/bin/env bash
# Read-only verification of the eight release-gating workflows on current main.
# Exit 0 = all successful, 1 = failed check or API error, 3 = pending/moved main.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
repo="${1:-mathiasseguincadiche/FEDORA_GNOME_CUSTOM}"
[[ $# -le 1 && "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo 'Usage: check-main-ci.sh [owner/repo]' >&2; exit 2; }
if ! command -v gh >/dev/null || ! command -v python3 >/dev/null; then
  echo 'gh and python3 required' >&2
  exit 2
fi
main_sha() {
  local sha
  sha="$(gh api "repos/$repo/git/ref/heads/main" --jq '.object.sha')" || return 1
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || return 1
  printf '%s\n' "$sha"
}
sha="$(main_sha)" || { echo 'Cannot resolve current main SHA' >&2; exit 1; }
printf 'Checking exact main SHA: %s\n' "$sha"
tmp="$(mktemp)"
trap 'rm -f -- "$tmp"' EXIT
gh api "repos/$repo/actions/runs?head_sha=$sha&event=push&per_page=100" > "$tmp" || exit 1
rc=0
python3 "$ROOT/scripts/ci/check-release-gate.py" "$sha" "$repo" < "$tmp" || rc=$?
[[ "$rc" == 0 ]] || exit "$rc"
latest="$(main_sha)" || exit 1
if [[ "$latest" != "$sha" ]]; then
  echo "Main advanced during verification ($latest); check the new SHA." >&2
  exit 3
fi
printf 'PASS: eight required push workflows succeeded on %s\n' "$sha"

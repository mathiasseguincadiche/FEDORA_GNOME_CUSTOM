#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/lib/gaming_repositories.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "Steam repository detection: FAIL: $*" >&2; exit 1; }
legacy="$tmp/etc/yum.repos.d/rpmfusion-nonfree-steam.repo"
vendor="$tmp/usr/share/dnf5/repos.d/rpmfusion-nonfree-steam.repo"
mkdir -p "$(dirname "$legacy")" "$(dirname "$vendor")"
if gaming_steam_repository_file "$tmp"; then fail 'absent definition accepted'; fi
printf '[rpmfusion-nonfree-steam]\nenabled=0\n' > "$vendor"
[[ "$(gaming_steam_repository_file "$tmp")" == "$vendor" ]] || fail 'Fedora 45 vendor definition not found'
cp "$vendor" "$legacy"
[[ "$(gaming_steam_repository_file "$tmp/")" == "$legacy" ]] || fail 'local administrative definition did not take precedence'
rm "$vendor"
[[ "$(gaming_steam_repository_file "$tmp")" == "$legacy" ]] || fail 'legacy definition not found'
rm "$legacy"
printf irrelevant > "$tmp/etc/yum.repos.d/unrelated.repo"
if gaming_steam_repository_file "$tmp"; then fail 'unrelated definition accepted'; fi
echo 'Steam repository detection: PASS (Fedora 45 location, legacy, precedence, missing, unrelated)'

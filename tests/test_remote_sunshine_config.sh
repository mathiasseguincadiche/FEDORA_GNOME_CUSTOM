#!/usr/bin/env bash
set -Eeuo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
conf="$tmp/sunshine.conf"
printf 'port = 47989\norigin_web_ui_allowed = lan\nupnp = on\n' > "$conf"
python3 "$root/scripts/remote/sunshine-config.py" "$conf"
python3 "$root/scripts/remote/sunshine-config.py" --check "$conf"
grep -Fxq 'port = 47989' "$conf"
grep -Fxq 'origin_web_ui_allowed = pc' "$conf"
grep -Fxq 'upnp = off' "$conf"
[[ "$(grep -c '^origin_web_ui_allowed' "$conf")" == 1 ]]
before="$(sha256sum "$conf")"
python3 "$root/scripts/remote/sunshine-config.py" "$conf"
[[ "$(sha256sum "$conf")" == "$before" ]]
printf 'origin_web_ui_allowed = wan\n' > "$conf"
if python3 "$root/scripts/remote/sunshine-config.py" --check "$conf"; then exit 1; fi
ln -s "$conf" "$tmp/alias.conf"
if python3 "$root/scripts/remote/sunshine-config.py" "$tmp/alias.conf" >/dev/null 2>&1; then
  echo 'Sunshine symlink unexpectedly accepted' >&2; exit 1
fi
echo 'sunshine config hardening: PASS'

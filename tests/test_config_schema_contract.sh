#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
validator="$ROOT/scripts/config/validate-config.sh"

[[ -x "$validator" || -r "$validator" ]]
[[ -r "$ROOT/config/schema.digest" ]]
[[ -r "$ROOT/config/schema-enums.tsv" ]]
bash "$validator" "$ROOT/config" >/dev/null
grep -Fq 'validate-config.sh' "$ROOT/lib/config.sh"
grep -Fq "bash \"\$validator\" \"\$REPO_ROOT/config\" >/dev/null" "$ROOT/lib/config.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -a "$ROOT/config" "$tmp/config"

printf 'DAILY_BACKUP_ENABLED="false"\n' > "$tmp/config/local.conf"
bash "$validator" "$tmp/config" >/dev/null

printf 'UNKNOWN_GOLDEN_KEY="true"\n' > "$tmp/config/local.conf"
if bash "$validator" "$tmp/config" >/dev/null 2>&1; then
  echo 'unknown local.conf key was accepted' >&2
  exit 1
fi

printf 'DAILY_BACKUP_ENABLED="tru"\n' > "$tmp/config/local.conf"
if bash "$validator" "$tmp/config" >/dev/null 2>&1; then
  echo 'invalid bool local.conf value was accepted' >&2
  exit 1
fi

marker="$tmp/command-executed"
printf "DAILY_BACKUP_ENABLED=\"\$(touch %s)\"\n" "$marker" > "$tmp/config/local.conf"
if bash "$validator" "$tmp/config" >/dev/null 2>&1; then
  echo 'command substitution syntax was accepted' >&2
  exit 1
fi
[[ ! -e "$marker" ]]

# A bare redirection is executable shell even though it looks like KEY=VALUE.
# It must be rejected before config_load can ever source local.conf.
redir_marker="$tmp/redirection-created"
printf 'BACKUP_PREAPPLY_CONFIRMATION_PHRASE=>%s\n' "$redir_marker" > "$tmp/config/local.conf"
if bash "$validator" "$tmp/config" >/dev/null 2>&1; then
  echo 'shell redirection syntax was accepted' >&2
  exit 1
fi
[[ ! -e "$redir_marker" ]]

printf 'BACKUP_PREAPPLY_CONFIRMATION_PHRASE=SAFE|cat\n' > "$tmp/config/local.conf"
if bash "$validator" "$tmp/config" >/dev/null 2>&1; then
  echo 'pipeline syntax was accepted' >&2
  exit 1
fi

# Quoted shell metacharacters used as literal application data remain valid.
printf 'SHOW_DESKTOP_PLUS_HOTKEY="<Super>d"\n' > "$tmp/config/local.conf"
bash "$validator" "$tmp/config" >/dev/null

rm -f "$tmp/config/local.conf"
printf 'ENABLE_KVM="true"\n' > "$tmp/config/duplicate.conf"
if bash "$validator" "$tmp/config" >/dev/null 2>&1; then
  echo 'duplicate canonical config key was accepted' >&2
  exit 1
fi

echo 'config schema contract: PASS'

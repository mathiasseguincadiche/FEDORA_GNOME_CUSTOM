#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for expected in \
  'BACKUP_PRUNE_AUTOMATICALLY="true"' \
  'BACKUP_RETENTION_TIMER_ENABLED="true"' \
  'BACKUP_RETENTION_ON_CALENDAR="Sun *-*-* 04:15:00"'; do
  grep -Fq "$expected" "$ROOT/config/backup.conf"
done

grep -Fq 'backup-runtime' "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq 'MANIFEST.sha256' "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq 'FEDORA_GNOME_CUSTOM_RUNTIME_ROOT=' "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq 'fedora-gnome-backup-retention.timer' "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq 'Refusing to replace invalid immutable backup runtime' "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq "install -m 0600 /dev/null \"\$output\"" "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq "mv -T -- \"\$tmp\" \"\$runtime_dir\"" "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq 'runtime/APPLIED_SHA' "$ROOT/lib/backup_runtime_bundle.sh"
if grep -Fq 'FEDORA_GNOME_CUSTOM_REPO=' "$ROOT/modules/backup/60_daily_user_backup.sh"; then
  echo 'daily backup systemd runtime still depends on checkout path' >&2
  exit 1
fi
grep -Fq 'backup_runtime_bundle_init' "$ROOT/scripts/backup/daily-user-backup.sh"
grep -Fq 'backup_runtime_bundle_init' "$ROOT/scripts/backup/backup-retention.sh"
grep -Fq 'backup-retention.sh" --strict' "$ROOT/scripts/backup/backup-now.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
runtime="$tmp/runtime"
mkdir -p "$runtime/bin" "$runtime/lib" "$runtime/runtime" "$tmp/bin" "$tmp/state" "$tmp/home"
cp "$ROOT/scripts/backup/backup-retention.sh" "$runtime/bin/backup-retention"
cp "$ROOT/lib/backup_runtime.sh" "$runtime/lib/backup_runtime.sh"
cp "$ROOT/lib/backup_runtime_bundle.sh" "$runtime/lib/backup_runtime_bundle.sh"
chmod +x "$runtime/bin/backup-retention"
printf 'BACKUP_REPOSITORY=%q\n' 'ssh://backup@nas.example/./fgc' > "$runtime/runtime/backup-runtime.conf"
printf 'BACKUP_KEEP_DAILY=%q\nBACKUP_KEEP_WEEKLY=%q\nBACKUP_KEEP_MONTHLY=%q\n' 7 4 6 >> "$runtime/runtime/backup-runtime.conf"
printf '%s\n' '0123456789abcdef0123456789abcdef01234567' > "$runtime/runtime/APPLIED_SHA"
(
  cd "$runtime"
  find bin lib runtime -type f -print0 | sort -z | xargs -0 sha256sum > MANIFEST.sha256
)
# Fake Borg: records every call; the repository reports encryption mode none.
cat > "$tmp/bin/borg" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s|repo=%s|passphrase=[%s]\n' "$*" "${BORG_REPO:-}" "${BORG_PASSPHRASE-unset}" >> "$BORG_TEST_LOG"
case "${1:-}" in
  --version) echo 'borg 1.4.5' ;;
  info) echo '{"encryption": {"mode": "none"}}' ;;
  prune|compact) exit 0 ;;
  *) exit 2 ;;
esac
SH
chmod +x "$tmp/bin/borg"

BORG_TEST_LOG="$tmp/borg.log" \
BORG_PASSPHRASE='ambient-secret-must-be-dropped' \
PATH="$tmp/bin:$PATH" \
HOME="$tmp/home" \
XDG_STATE_HOME="$tmp/state" \
FEDORA_GNOME_CUSTOM_RUNTIME_ROOT="$runtime" \
bash "$runtime/bin/backup-retention"

grep -Fq 'prune --glob-archives fgc-full-* --keep-daily 7 --keep-weekly 4 --keep-monthly 6|repo=ssh://backup@nas.example/./fgc' "$tmp/borg.log"
grep -Fq 'prune --glob-archives fgc-daily-* --keep-daily 7 --keep-weekly 4 --keep-monthly 6|' "$tmp/borg.log"
if grep -Fq 'fgc-preapply' "$tmp/borg.log"; then echo 'retention touched pre-APPLY archives' >&2; exit 1; fi
[[ "$(grep -c '^compact|' "$tmp/borg.log")" -eq 1 ]]
if grep -Fq 'ambient-secret-must-be-dropped' "$tmp/borg.log"; then echo 'ambient BORG_PASSPHRASE leaked into Borg' >&2; exit 1; fi
[[ -s "$tmp/state/fedora-gnome-custom/last-retention.ok" ]]
grep -Fxq 'engine=borg' "$tmp/state/fedora-gnome-custom/last-retention.ok"

# Missing APPLIED_SHA must fail at the installed-runtime sanity gate with a
# controlled precheck error, before any runtime config is sourced.
cp -a "$runtime" "$tmp/runtime-missing-sha"
rm -f "$tmp/runtime-missing-sha/runtime/APPLIED_SHA"
if FEDORA_GNOME_CUSTOM_RUNTIME_ROOT="$tmp/runtime-missing-sha" bash -c 'source "$1"; backup_runtime_bundle_init' _ "$tmp/runtime-missing-sha/lib/backup_runtime_bundle.sh" >/dev/null 2>&1; then
  echo 'runtime without APPLIED_SHA was accepted' >&2
  exit 1
fi

echo 'backup runtime bundle contract: PASS'

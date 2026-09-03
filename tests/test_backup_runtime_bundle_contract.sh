#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for expected in \
  'BACKUP_PRUNE_AUTOMATICALLY="true"' \
  'RESTIC_RETENTION_TIMER_ENABLED="true"' \
  'RESTIC_RETENTION_ON_CALENDAR="Sun *-*-* 04:15:00"'; do
  grep -Fq "$expected" "$ROOT/config/backup.conf"
done

grep -Fq 'backup-runtime' "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq 'MANIFEST.sha256' "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq 'FEDORA_GNOME_CUSTOM_RUNTIME_ROOT=' "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq 'fedora-gnome-restic-retention.timer' "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq 'Refusing to replace invalid immutable backup runtime' "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq "install -m 0600 /dev/null \"\$output\"" "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq "mv -T -- \"\$tmp\" \"\$runtime_dir\"" "$ROOT/modules/backup/60_daily_user_backup.sh"
grep -Fq 'runtime/APPLIED_SHA' "$ROOT/lib/backup_runtime_bundle.sh"
if grep -Fq 'FEDORA_GNOME_CUSTOM_REPO=' "$ROOT/modules/backup/60_daily_user_backup.sh"; then
  echo 'daily backup systemd runtime still depends on checkout path' >&2
  exit 1
fi
grep -Fq 'backup_runtime_bundle_init' "$ROOT/scripts/backup/daily-user-backup.sh"
grep -Fq 'backup_runtime_bundle_init' "$ROOT/scripts/backup/restic-retention.sh"
grep -Fq -- '--group-by host,tags' "$ROOT/scripts/backup/restic-retention.sh"
grep -Fq 'restic-retention.sh" --strict' "$ROOT/scripts/backup/backup-now.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
runtime="$tmp/runtime"
mkdir -p "$runtime/bin" "$runtime/lib" "$runtime/runtime" "$tmp/bin" "$tmp/state" "$tmp/home/.config/fedora-gnome-custom/secrets"
cp "$ROOT/scripts/backup/restic-retention.sh" "$runtime/bin/restic-retention"
cp "$ROOT/lib/backup_runtime.sh" "$runtime/lib/backup_runtime.sh"
cp "$ROOT/lib/backup_runtime_bundle.sh" "$runtime/lib/backup_runtime_bundle.sh"
chmod +x "$runtime/bin/restic-retention"
printf 'BACKUP_REPOSITORY=%q\n' 'sftp:test-repository' > "$runtime/runtime/backup-runtime.conf"
printf 'BACKUP_PASSWORD_FILE=%q\n' "$tmp/password" >> "$runtime/runtime/backup-runtime.conf"
printf 'RESTIC_KEEP_DAILY=%q\nRESTIC_KEEP_WEEKLY=%q\nRESTIC_KEEP_MONTHLY=%q\n' 7 4 6 >> "$runtime/runtime/backup-runtime.conf"
printf '%s\n' '0123456789abcdef0123456789abcdef01234567' > "$runtime/runtime/APPLIED_SHA"
printf 'not-a-secret-test-password\n' > "$tmp/password"
chmod 0600 "$tmp/password"
(
  cd "$runtime"
  find bin lib runtime -type f -print0 | sort -z | xargs -0 sha256sum > MANIFEST.sha256
)
cat > "$tmp/bin/restic" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" >> "$RESTIC_TEST_LOG"
case "${1:-}" in
  cat|forget|prune) exit 0 ;;
  *) exit 1 ;;
esac
SH
chmod +x "$tmp/bin/restic"

RESTIC_TEST_LOG="$tmp/restic.log" \
PATH="$tmp/bin:$PATH" \
HOME="$tmp/home" \
XDG_STATE_HOME="$tmp/state" \
FEDORA_GNOME_CUSTOM_RUNTIME_ROOT="$runtime" \
bash "$runtime/bin/restic-retention"

grep -Fq 'forget --tag fedora-gnome-custom-full --group-by host,tags --keep-daily 7 --keep-weekly 4 --keep-monthly 6' "$tmp/restic.log"
grep -Fq 'forget --tag fedora-gnome-custom-daily --group-by host,tags --keep-daily 7 --keep-weekly 4 --keep-monthly 6' "$tmp/restic.log"
[[ "$(grep -c '^prune$' "$tmp/restic.log")" -eq 1 ]]
[[ -s "$tmp/state/fedora-gnome-custom/last-retention.ok" ]]
grep -Fq 'group_by=host,tags' "$tmp/state/fedora-gnome-custom/last-retention.ok"

# Missing APPLIED_SHA must fail at the installed-runtime sanity gate with a
# controlled precheck error, before any runtime config is sourced.
cp -a "$runtime" "$tmp/runtime-missing-sha"
rm -f "$tmp/runtime-missing-sha/runtime/APPLIED_SHA"
if FEDORA_GNOME_CUSTOM_RUNTIME_ROOT="$tmp/runtime-missing-sha" bash -c 'source "$1"; backup_runtime_bundle_init' _ "$tmp/runtime-missing-sha/lib/backup_runtime_bundle.sh" >/dev/null 2>&1; then
  echo 'runtime without APPLIED_SHA was accepted' >&2
  exit 1
fi

echo 'backup runtime bundle contract: PASS'

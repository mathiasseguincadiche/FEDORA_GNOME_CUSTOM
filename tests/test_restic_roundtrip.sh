#!/usr/bin/env bash
# Real encryption, backup, full data read and restore. Only the external-disk
# predicate is replaced in this disposable fixture; this is not Gate 3 evidence.
# shellcheck disable=SC2034,SC2016
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v restic >/dev/null || { echo 'restic required for roundtrip integration test' >&2; exit 20; }
command -v jq >/dev/null || exit 20
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" XDG_STATE_HOME="$tmp/state" LC_ALL=C
export RESTIC_CACHE_DIR="$tmp/cache"
fixture="$tmp/checkout"
mkdir -p "$fixture/scripts/backup" "$fixture/lib" "$fixture/config" "$fixture/systemd/user" "$HOME/.config/fedora-gnome-custom/secrets" "$HOME/.var/app/demo/data" "$HOME/.local/share/demo" "$HOME/.mozilla"
cp "$ROOT"/scripts/backup/{daily-user-backup.sh,restic-retention.sh,restore.sh} "$fixture/scripts/backup/"
cp "$ROOT"/lib/{backup_runtime.sh,backup_runtime_bundle.sh} "$fixture/lib/"
cp "$ROOT/config/backup.conf" "$fixture/config/"
cp "$ROOT/systemd/user/fedora-gnome-daily-backup.timer" "$fixture/systemd/user/"
# The only mocked condition: no physical USB disk exists in CI. Scope it to
# this one temporary repository; production code never gains a bypass flag.
cat >> "$fixture/lib/backup_runtime.sh" <<'MOCK'
backup_runtime_validate_local_target() { [[ "$1" == "$FGC_TEST_REPOSITORY" ]]; }
MOCK
export FGC_TEST_REPOSITORY="$tmp/restic-repository"
export BACKUP_REPOSITORY="$FGC_TEST_REPOSITORY"
export BACKUP_PASSWORD_FILE="$HOME/.config/fedora-gnome-custom/secrets/restic-password"
printf 'test-only-passphrase-not-a-real-secret\n' > "$BACKUP_PASSWORD_FILE"
chmod 0600 "$BACKUP_PASSWORD_FILE"
export RESTIC_REPOSITORY="$BACKUP_REPOSITORY" RESTIC_PASSWORD_FILE="$BACKUP_PASSWORD_FILE"
restic init >/dev/null
printf 'réglages GNOME et données\n' > "$HOME/.config/test.conf"
chmod 0600 "$HOME/.config/test.conf"
printf 'flatpak-data\n' > "$HOME/.var/app/demo/data/document with spaces.txt"
printf 'application-data\n' > "$HOME/.local/share/demo/state"
printf 'browser-profile\n' > "$HOME/.mozilla/profile"
ln -s test.conf "$HOME/.config/link"
cat > "$fixture/lib/bootstrap.sh" <<'BOOT'
engine_bootstrap() { :; }
BOOT
source "$ROOT/modules/backup/60_daily_user_backup.sh"
REPO_ROOT="$fixture"
EXIT_APPLY_FAILED=30
DAILY_BACKUP_XDG_DIRS=''
# Disable XDG lookup by choosing one deterministic mocked xdg-user-dir.
mkdir -p "$tmp/bin" "$HOME/Documents"
printf '#!/usr/bin/env bash\nprintf "%%s/Documents\\n" "$HOME"\n' > "$tmp/bin/xdg-user-dir"
chmod +x "$tmp/bin/xdg-user-dir"
export PATH="$tmp/bin:$PATH"
DAILY_BACKUP_XDG_DIRS=DOCUMENTS
DAILY_BACKUP_EXTRA_PATHS='.config .var/app .local/share .mozilla'
runtime="$(backup_daily_install_runtime 0123456789abcdef0123456789abcdef01234567)"
FEDORA_GNOME_CUSTOM_RUNTIME_ROOT="$runtime" bash "$runtime/bin/daily-user-backup"
snapshot="$(jq -r '.[0].id' < <(restic snapshots --json))"
[[ "$snapshot" =~ ^[0-9a-f]{64}$ ]]
restic check --read-data >/dev/null
bash "$fixture/scripts/backup/restore.sh" restore "$snapshot" "$tmp/restored"
for file in '.config/test.conf' '.var/app/demo/data/document with spaces.txt' '.local/share/demo/state' '.mozilla/profile'; do
  cmp "$HOME/$file" "$tmp/restored$HOME/$file"
done
[[ "$(stat -c %a "$tmp/restored$HOME/.config/test.conf")" == 600 ]]
[[ "$(readlink "$tmp/restored$HOME/.config/link")" == test.conf ]]
[[ ! -e "$tmp/restored$BACKUP_PASSWORD_FILE" ]]
if bash "$fixture/scripts/backup/restore.sh" restore "$snapshot" "$tmp/restored" >/dev/null 2>&1; then
  echo 'nonempty restore destination accepted' >&2; exit 1
fi
if bash "$fixture/scripts/backup/restore.sh" restore "$snapshot" "$HOME" >/dev/null 2>&1; then
  echo 'in-place restore accepted' >&2; exit 1
fi
printf 'wrong password\n' > "$tmp/wrong-password"
if RESTIC_PASSWORD_FILE="$tmp/wrong-password" restic snapshots >/dev/null 2>&1; then
  echo 'wrong Restic password accepted' >&2; exit 1
fi
printf 'Restic roundtrip: PASS (real data, permissions, symlink, secret exclusion, fail-closed restore)\n'

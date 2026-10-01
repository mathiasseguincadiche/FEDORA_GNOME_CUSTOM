#!/usr/bin/env bash
# Real Borg backup, retention, full data verification and restore on an
# UNENCRYPTED repository (ADR 0014). Only the external-disk predicate is
# replaced in this disposable fixture; this is not Gate 3 evidence.
# shellcheck disable=SC2034,SC2016,SC2030,SC2031
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v borg >/dev/null || { echo 'borg required for roundtrip integration test' >&2; exit 20; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" XDG_STATE_HOME="$tmp/state" LC_ALL=C
export BORG_BASE_DIR="$tmp/borg-base"
fixture="$tmp/checkout"
mkdir -p "$fixture/scripts/backup" "$fixture/lib" "$fixture/config" "$fixture/systemd/user" "$HOME/.config/fedora-gnome-custom/secrets" "$HOME/.var/app/demo/data" "$HOME/.local/share/demo" "$HOME/.mozilla"
cp "$ROOT"/scripts/backup/{daily-user-backup.sh,backup-retention.sh,restore.sh} "$fixture/scripts/backup/"
cp "$ROOT"/lib/{backup_runtime.sh,backup_runtime_bundle.sh} "$fixture/lib/"
cp "$ROOT/config/backup.conf" "$fixture/config/"
cp "$ROOT/systemd/user/fedora-gnome-daily-backup.timer" "$fixture/systemd/user/"
# The only mocked condition: no physical USB disk exists in CI. Scope it to
# this one temporary repository; production code never gains a bypass flag.
cat >> "$fixture/lib/backup_runtime.sh" <<'MOCK'
backup_runtime_validate_local_target() { [[ "$1" == "$FGC_TEST_REPOSITORY" ]]; }
MOCK
export FGC_TEST_REPOSITORY="$tmp/borg-repository"
export BACKUP_REPOSITORY="$FGC_TEST_REPOSITORY"
# shellcheck source=lib/backup_runtime.sh
source "$ROOT/lib/backup_runtime.sh"
backup_engine_env "$BACKUP_REPOSITORY"
backup_engine_init >/dev/null
printf 'réglages GNOME et données\n' > "$HOME/.config/test.conf"
chmod 0600 "$HOME/.config/test.conf"
printf 'flatpak-data\n' > "$HOME/.var/app/demo/data/document with spaces.txt"
printf 'application-data\n' > "$HOME/.local/share/demo/state"
printf 'browser-profile\n' > "$HOME/.mozilla/profile"
printf 'must-not-be-archived\n' > "$HOME/.config/fedora-gnome-custom/secrets/token"
ln -s test.conf "$HOME/.config/link"
cat > "$fixture/lib/bootstrap.sh" <<'BOOT'
engine_bootstrap() { :; }
BOOT
source "$ROOT/modules/backup/60_daily_user_backup.sh"
REPO_ROOT="$fixture"
EXIT_APPLY_FAILED=30
mkdir -p "$tmp/bin" "$HOME/Documents"
printf '#!/usr/bin/env bash\nprintf "%%s/Documents\\n" "$HOME"\n' > "$tmp/bin/xdg-user-dir"
chmod +x "$tmp/bin/xdg-user-dir"
export PATH="$tmp/bin:$PATH"
DAILY_BACKUP_XDG_DIRS=DOCUMENTS
DAILY_BACKUP_EXTRA_PATHS='.config .var/app .local/share .mozilla'

# 1. The installed autonomous runtime writes a real daily archive.
runtime="$(backup_daily_install_runtime 0123456789abcdef0123456789abcdef01234567)"
FEDORA_GNOME_CUSTOM_RUNTIME_ROOT="$runtime" bash "$runtime/bin/daily-user-backup"
read -r archive archive_id < <(backup_engine_latest daily)
[[ "$archive" == fgc-daily-* && "$archive_id" =~ ^[0-9a-f]{64}$ ]]
grep -Fxq "archive=$archive" "$XDG_STATE_HOME/fedora-gnome-custom/last-daily-backup.ok"
grep -Fxq "snapshot=$archive_id" "$XDG_STATE_HOME/fedora-gnome-custom/last-daily-backup.ok"
borg check --verify-data >/dev/null 2>&1

# 2. The repository is really unencrypted, as decided by the owner.
[[ "$(borg info --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["encryption"]["mode"])')" == none ]]

# 3. Staging-only restore: content, permissions, symlink, secrets excluded.
restored="$HOME/Restores/fedora-gnome-custom/roundtrip"
bash "$fixture/scripts/backup/restore.sh" restore "$archive" "$restored"
for file in '.config/test.conf' '.var/app/demo/data/document with spaces.txt' '.local/share/demo/state' '.mozilla/profile'; do
  cmp "$HOME/$file" "$restored$HOME/$file"
done
[[ "$(stat -c %a "$restored$HOME/.config/test.conf")" == 600 ]]
[[ "$(readlink "$restored$HOME/.config/link")" == test.conf ]]
[[ ! -e "$restored$HOME/.config/fedora-gnome-custom/secrets/token" ]]
if bash "$fixture/scripts/backup/restore.sh" restore "$archive" "$restored" >/dev/null 2>&1; then
  echo 'nonempty restore destination accepted' >&2; exit 1
fi
if bash "$fixture/scripts/backup/restore.sh" restore "$archive" "$HOME" >/dev/null 2>&1; then
  echo 'in-place restore accepted' >&2; exit 1
fi
if bash "$fixture/scripts/backup/restore.sh" restore 'fgc-daily-x;rm -rf ~' >/dev/null 2>&1; then
  echo 'malformed archive name accepted' >&2; exit 1
fi

# 4. Retention keeps a policy-bounded set and compacts; it never touches pre-APPLY.
read -r pre _ < <(backup_engine_create preapply -- "$HOME/.config")
FEDORA_GNOME_CUSTOM_RUNTIME_ROOT="$runtime" bash "$runtime/bin/backup-retention" --strict >/dev/null
grep -Fxq 'prune=PASS' "$XDG_STATE_HOME/fedora-gnome-custom/last-retention.ok"
borg list --short | grep -Fxq "$pre"

# 5. The pre-APPLY marker re-opens exactly its archive: name, id and kind.
(
  source "$ROOT/lib/evidence.sh"
  source "$fixture/lib/backup_runtime.sh"   # fixture: external-disk predicate mocked
  backup_engine_env "$BACKUP_REPOSITORY"
  read -r pre_name pre_id < <(backup_engine_latest preapply)
  marker="$tmp/preapply-backup.ok"
  printf 'verdict=PASS\nintegrity_check=PASS\nrestore_test=PASS\nsnapshot=%s\narchive=%s\nrepository=%s\n' "$pre_id" "$pre_name" "$BACKUP_REPOSITORY" > "$marker"
  backup_runtime_validate_preapply_marker "$marker"
  printf 'snapshot=%s\narchive=%s\nrepository=%s\n' "$archive_id" "$archive" "$BACKUP_REPOSITORY" > "$marker"
  if backup_runtime_validate_preapply_marker "$marker"; then echo 'daily archive accepted as pre-APPLY proof' >&2; exit 1; fi
  printf 'snapshot=%s\narchive=%s\nrepository=%s\n' "$(printf '%064d' 0)" "$pre_name" "$BACKUP_REPOSITORY" > "$marker"
  if backup_runtime_validate_preapply_marker "$marker"; then echo 'forged archive id accepted' >&2; exit 1; fi
)

# An attempted backup with a warning cannot retain yesterday's success marker.
FGC_REAL_BORG="$(command -v borg)"
export FGC_REAL_BORG
cat > "$tmp/bin/borg" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == create ]]; then
  printf '{"archive":{"name":"ignored","id":"%064d"}}\n' 1
  exit "${FGC_CREATE_RC:-1}"
fi
exec "$FGC_REAL_BORG" "$@"
MOCK
chmod +x "$tmp/bin/borg"
for FGC_CREATE_RC in 1 2; do
  export FGC_CREATE_RC
  rc=0
  FEDORA_GNOME_CUSTOM_RUNTIME_ROOT="$runtime" bash "$runtime/bin/daily-user-backup" >/dev/null 2>&1 || rc=$?
  [[ "$rc" == 40 && ! -e "$XDG_STATE_HOME/fedora-gnome-custom/last-daily-backup.ok" ]]
  [[ -s "$XDG_STATE_HOME/fedora-gnome-custom/last-daily-backup.failed" ]]
done
rm "$tmp/bin/borg"
FEDORA_GNOME_CUSTOM_RUNTIME_ROOT="$runtime" bash "$runtime/bin/daily-user-backup"
[[ -s "$XDG_STATE_HOME/fedora-gnome-custom/last-daily-backup.ok" ]]
[[ ! -e "$XDG_STATE_HOME/fedora-gnome-custom/last-daily-backup.failed" ]]

# 6. An encrypted repository is refused by policy (and never prompts).
enc="$tmp/encrypted"
BORG_PASSPHRASE=test-only-not-a-secret borg init --encryption=repokey "$enc" </dev/null >/dev/null 2>&1
backup_engine_env "$enc"
if timeout 60 bash -c 'source "$1"; backup_engine_env "$2"; backup_engine_repo_ready' bash "$ROOT/lib/backup_runtime.sh" "$enc" </dev/null; then
  echo 'encrypted repository accepted' >&2; exit 1
fi
printf 'Borg roundtrip: PASS (unencrypted repo, real data, verify-data, permissions, symlink, secret exclusion, retention, fail-closed restore)\n'

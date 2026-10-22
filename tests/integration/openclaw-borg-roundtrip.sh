#!/usr/bin/env bash
# Run only in a disposable root container: real /data paths and real Borg,
# simulated findmnt/lsblk hardware. This is not physical certification.
# shellcheck disable=SC2034,SC2016
set -Eeuo pipefail
[[ "$EUID" == 0 && -f /.dockerenv && ! -e /data ]] || {
  echo 'This test requires a disposable root Docker container without /data.' >&2; exit 20;
}
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp" /data' EXIT
export HOME="$tmp/home" XDG_STATE_HOME="$tmp/state" BORG_BASE_DIR="$tmp/borg-base"
export FGC_TEST_REPOSITORY="$tmp/borg" BACKUP_REPOSITORY="$tmp/borg"
fixture="$tmp/checkout"
mkdir -p "$fixture/scripts/backup" "$fixture/lib" "$fixture/config" "$tmp/bin" "$HOME/Documents" /data/Projets /data/IA/Openclaw
cp "$ROOT"/scripts/backup/{daily-user-backup.sh,backup-retention.sh} "$fixture/scripts/backup/"
cp "$ROOT"/lib/{backup_runtime.sh,backup_runtime_bundle.sh,persistent_data.sh,persistent_data_identity.py} "$fixture/lib/"
cp "$ROOT/config/backup.conf" "$fixture/config/"
cat >> "$fixture/lib/backup_runtime.sh" <<'MOCK'
backup_runtime_validate_local_target() { [[ "$1" == "$FGC_TEST_REPOSITORY" ]]; }
MOCK
cat > "$tmp/bin/findmnt" <<'MOCK'
#!/usr/bin/env python3
import json,sys
target=sys.argv[3]
i=1 if target == '/data' else 0
print(json.dumps({'filesystems':[dict(source=f'/dev/nvme{i}n1p2',target=target,
    fstype='ext4' if i else 'btrfs',uuid=f'00000000-0000-4000-8000-00000000000{i}',options='rw,relatime')]}))
MOCK
cat > "$tmp/bin/lsblk" <<'MOCK'
#!/usr/bin/env python3
import json,sys
i=1 if sys.argv[-1] == '/dev/nvme1n1p2' else 0
print(json.dumps({'blockdevices':[dict(name=f'/dev/nvme{i}n1',type='disk',
    model='CT1000T705SSD3',serial=f'T705-{i}',wwn=f'eui.{i}')]}))
MOCK
printf '#!/usr/bin/env bash\nprintf "%%s/Documents\\n" "$HOME"\n' > "$tmp/bin/xdg-user-dir"
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
REPO_ROOT="$fixture"
source "$ROOT/lib/backup_runtime.sh"
source "$ROOT/lib/persistent_data.sh"
source "$ROOT/modules/backup/60_daily_user_backup.sh"
EXIT_APPLY_FAILED=30
mkdir -p "$HOME"
persistent_data_enroll T705-1 >/dev/null
backup_engine_env "$BACKUP_REPOSITORY"
backup_engine_init >/dev/null
DAILY_BACKUP_XDG_DIRS=DOCUMENTS
DAILY_BACKUP_EXTRA_PATHS='/data/Projets /data/IA/Openclaw'
printf 'Openclaw sources\n' > /data/IA/Openclaw/source.txt
printf 'DevOps sources\n' > /data/Projets/source.txt
printf 'manual VM image\n' > /data/IA/Openclaw/manual.qcow2
runtime="$(backup_daily_install_runtime 0123456789abcdef0123456789abcdef01234567)"
FEDORA_GNOME_CUSTOM_RUNTIME_ROOT="$runtime" bash "$runtime/bin/daily-user-backup"
read -r archive _ < <(backup_engine_latest daily)
mkdir "$tmp/restore"
(cd "$tmp/restore" && borg extract "::$archive")
cmp /data/IA/Openclaw/source.txt "$tmp/restore/data/IA/Openclaw/source.txt"
cmp /data/Projets/source.txt "$tmp/restore/data/Projets/source.txt"
[[ ! -e "$tmp/restore/data/IA/Openclaw/manual.qcow2" ]]

# The immutable timer runtime must reject an actual mount identity change,
# invalidate its previous PASS and leave no new certified archive.
sed -i "s/T705-{i}/OTHER-{i}/" "$tmp/bin/lsblk"
rc=0
FEDORA_GNOME_CUSTOM_RUNTIME_ROOT="$runtime" bash "$runtime/bin/daily-user-backup" > "$tmp/refused.log" 2>&1 || rc=$?
[[ "$rc" == 20 && ! -e "$XDG_STATE_HOME/fedora-gnome-custom/last-daily-backup.ok" ]]
echo 'Openclaw real Borg roundtrip, VM exclusion and changed-disk refusal: PASS'

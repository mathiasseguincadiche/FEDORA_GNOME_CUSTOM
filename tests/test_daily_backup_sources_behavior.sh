#!/usr/bin/env bash
# Real execution of scripts/backup/daily-user-backup.sh from an installed
# runtime fixture, with a fake Borg that records what it is asked to archive:
# locale-safe XDG sources, approved extra paths only, VM images and libvirt
# excluded, /data refused unless it is the validated second NVMe.
# shellcheck disable=SC2016
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "daily backup sources behavior: FAIL: $*" >&2; exit 1; }

export HOME="$tmp/home" FAKE_ARGS="$tmp/borg-create" FAKE_TMP="$tmp"
export FEDORA_GNOME_CUSTOM_STATE_ROOT="$tmp/state" FEDORA_GNOME_CUSTOM_RUNTIME_ROOT="$tmp/runtime"
state="$FEDORA_GNOME_CUSTOM_STATE_ROOT"
mkdir -p "$tmp/bin" "$tmp/runtime/lib" "$tmp/runtime/runtime" "$tmp/repo"

# French XDG names prove sources come from xdg-user-dir, not English defaults.
for dir in Bureau Documents Images Vidéos Musique .config .mozilla .var/app .local/share Jeux; do
  mkdir -p "$HOME/$dir"
done
touch "$HOME/Documents/rapport.odt" "$HOME/.config/settings"

# Installed runtime: real backup helpers, simulated /data validation.
cp "$ROOT/lib/backup_runtime_bundle.sh" "$ROOT/lib/backup_runtime.sh" "$tmp/runtime/lib/"
cat >> "$tmp/runtime/lib/backup_runtime.sh" <<'SH'
backup_runtime_validate_local_target() { [[ "$1" == "$FAKE_TMP/repo" ]]; }
SH
cat > "$tmp/runtime/lib/persistent_data.sh" <<'SH'
persistent_data_validate_mount() { [[ "${FAKE_DATA_MOUNT:-invalid}" == valid ]]; }
persistent_data_validate_user_path() { return 0; }
SH
printf 'BACKUP_REPOSITORY="%s"\n' "$tmp/repo" > "$tmp/runtime/runtime/backup-runtime.conf"
printf '%040d\n' 7 > "$tmp/runtime/runtime/APPLIED_SHA"
(cd "$tmp/runtime" && sha256sum lib/* runtime/* > MANIFEST.sha256)

cat > "$tmp/bin/borg" <<'SH'
#!/usr/bin/env bash
id=$(printf '%064d' 1)
case "$1" in
  --version) echo 'borg 1.2.8' ;;
  create)
    printf '%s\n' "$@" > "$FAKE_ARGS"
    for arg; do [[ "$arg" == ::* ]] && name="${arg#::}"; done
    printf '{"archive": {"name": "%s", "id": "%s"}}\n' "$name" "$id" ;;
  rename) ;;
  info)
    if [[ "${3:-}" == ::* ]]; then printf '{"archives": [{"name": "%s", "id": "%s"}]}\n' "${3#::}" "$id"
    else echo '{"encryption": {"mode": "none"}}'; fi ;;
esac
SH
cat > "$tmp/bin/xdg-user-dir" <<'SH'
#!/usr/bin/env bash
case "$1" in
  DESKTOP) echo "$HOME/Bureau" ;; DOCUMENTS) echo "$HOME/Documents" ;; PICTURES) echo "$HOME/Images" ;;
  VIDEOS) echo "$HOME/Vidéos" ;; MUSIC) echo "${FAKE_MUSIC:-$HOME/Musique}" ;; *) exit 1 ;;
esac
SH
cat > "$tmp/bin/findmnt" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"

# Shipped defaults; the extra paths include /data, so /data validation is exercised.
eval "$(grep -E '^DAILY_BACKUP_(XDG_DIRS|EXTRA_PATHS)=' "$ROOT/config/backup.conf")"
export DAILY_BACKUP_XDG_DIRS DAILY_BACKUP_EXTRA_PATHS
run_daily() { rm -f "$FAKE_ARGS"; bash "$ROOT/scripts/backup/daily-user-backup.sh" > "$tmp/out" 2>&1; }
expect_refused() {
  local want="$1" rc=0; shift
  rm -f "$FAKE_ARGS"
  env "$@" bash "$ROOT/scripts/backup/daily-user-backup.sh" > "$tmp/out" 2>&1 || rc=$?
  [[ "$rc" == "$want" ]] || { cat "$tmp/out" >&2; fail "$* returned $rc, expected $want"; }
  [[ ! -e "$FAKE_ARGS" ]] || fail "$* still reached borg create"
}
sources() { awk 'f; /^::fgc-pending-daily-/ {f=1}' "$FAKE_ARGS"; }
excludes() { awk 'p=="--exclude" {print} {p=$0}' "$FAKE_ARGS"; }

# /data in the sources but not the validated second NVMe: refused before Borg.
expect_refused 20 FAKE_DATA_MOUNT=invalid
grep -Fq '/data is not the dedicated EXT4 second T705' "$tmp/out" || fail '/data refusal not explained'
[[ -s "$state/last-daily-backup.failed" ]] || fail 'refusal left no failure marker'

# Valid /data: the archive gets the XDG directories and the existing home extras.
export FAKE_DATA_MOUNT=valid
run_daily || { cat "$tmp/out" >&2; fail 'daily backup failed'; }
for dir in Bureau Documents Images Vidéos Musique .config .mozilla .var/app .local/share; do
  sources | grep -Fxq "$HOME/$dir" || fail "daily archive misses $dir"
done
if sources | grep -Fq -e Jeux -e /data/ISO -e "$HOME/.ssh"; then fail 'daily archive includes a non-approved source'; fi
for pattern in '*.qcow2' '*.vmdk' '*.raw' '*/libvirt/*' "$HOME/.config/fedora-gnome-custom/secrets" '*/.ssh' '*/.gnupg'; do
  excludes | grep -Fxq -- "$pattern" || fail "daily archive does not exclude $pattern"
done
marker="$state/last-daily-backup.ok"
grep -Fxq 'verdict=PASS' "$marker" || fail 'no success marker'
grep -Fxq "source_count=$(sources | wc -l)" "$marker" || fail 'marker source count differs from the archive'
grep -Fxq "runtime_sha=$(printf '%040d' 7)" "$marker" || fail 'marker does not name the installed runtime'
[[ ! -e "$state/last-daily-backup.failed" ]] || fail 'stale failure marker kept after success'

# A duplicate XDG mapping is archived once.
FAKE_MUSIC="$HOME/Documents" run_daily || fail 'duplicate XDG mapping rejected'
[[ "$(sources | grep -Fxc "$HOME/Documents")" == 1 ]] || fail 'duplicate source archived twice'

# Unsafe configuration is refused before Borg.
expect_refused 60 DAILY_BACKUP_EXTRA_PATHS=/data/Jeux
expect_refused 60 DAILY_BACKUP_EXTRA_PATHS=/data/ISO
expect_refused 60 DAILY_BACKUP_EXTRA_PATHS=/etc
expect_refused 60 DAILY_BACKUP_EXTRA_PATHS=../other-user
expect_refused 60 DAILY_BACKUP_XDG_DIRS=DOWNLOAD
expect_refused 60 FAKE_MUSIC="$HOME"
grep -Fq 'ambiguous XDG MUSIC' "$tmp/out" || fail 'XDG mapped to HOME not explained'

# A tampered installed runtime is refused before Borg.
printf '# edited\n' >> "$tmp/runtime/lib/persistent_data.sh"
expect_refused 20 FAKE_DATA_MOUNT=valid
grep -Fq 'integrity check failed' "$tmp/out" || fail 'runtime tampering not explained'

echo 'daily backup sources behavior: PASS'

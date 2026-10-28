#!/usr/bin/env bash
# Real full archive creation and exact-archive certification in a disposable
# fixture. The platform/inventory commands are simulated, never Gate 3 proof.
# shellcheck disable=SC2016,SC2034,SC1090
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" BORG_BASE_DIR="$tmp/borg-base"
export RUN_ID=full-backup-fixture
export BACKUP_REPOSITORY="$tmp/borg" STATE_ROOT="$tmp/state"
# Host-independent: the 20 GiB production reserve would make this test depend
# on the free space of whoever runs it. Staging capacity is still exercised.
export BACKUP_PREAPPLY_MIN_FREE_GIB=1
export REPO_ROOT="$tmp/fixture"
mkdir -p "$REPO_ROOT/config"
printf 'ROCKY_SERVER_NAME="owner-local-machine"\n' > "$REPO_ROOT/config/local.conf"
mkdir -p "$HOME/.config" "$STATE_ROOT" "$REPO_ROOT/lib" "$REPO_ROOT/scripts/backup" "$tmp/bin"
cp "$ROOT/lib/backup_runtime.sh" "$REPO_ROOT/lib/"
cp "$ROOT/lib/evidence.sh" "$REPO_ROOT/lib/"
cp "$ROOT/scripts/backup/backup-now.sh" "$REPO_ROOT/scripts/backup/"
printf 'settings\n' > "$HOME/.config/settings"
# Ensure a VM metadata file under an otherwise approved directory is excluded.
mkdir -p "$HOME/.config/libvirt"
printf 'private owner-managed VM XML\n' > "$HOME/.config/libvirt/manual-domain.xml"
cat > "$REPO_ROOT/lib/install_lock.sh" <<'MOCK'
install_lock_acquire() { return 0; }
MOCK
# /data is a fixture directory; its mount check is simulated.
cat > "$REPO_ROOT/lib/persistent_data.sh" <<'MOCK'
persistent_data_validate_mount() { [[ "${TEST_DATA_MOUNT:-invalid}" == valid ]]; }
persistent_data_validate_user_path() { return 0; }
persistent_data_documents() { printf '%s/Documents\n' "$TEST_DATA"; }
persistent_data_projects() { printf '%s/Projets\n' "$TEST_DATA"; }
persistent_data_openclaw() { printf '%s/IA/Openclaw\n' "$TEST_DATA"; }
MOCK
export TEST_DATA="$tmp/data" TEST_SYSROOT="$tmp/sysroot"
mkdir -p "$TEST_DATA/Documents" "$TEST_DATA/Projets" "$TEST_DATA/Jeux" "$TEST_DATA/ISO"
touch "$TEST_DATA/Documents/facture.pdf" "$TEST_DATA/Projets/main.py" "$TEST_DATA/Jeux/game.bin" "$TEST_DATA/ISO/fedora.iso"
mkdir -p "$TEST_SYSROOT/etc/libvirt/qemu" "$TEST_SYSROOT/boot"
printf 'host\n' > "$TEST_SYSROOT/etc/hostname"
printf 'private domain XML\n' > "$TEST_SYSROOT/etc/libvirt/qemu/owner-managed.xml"
touch "$TEST_SYSROOT/boot/vmlinuz-fixture"
cat > "$REPO_ROOT/lib/bootstrap.sh" <<'MOCK'
engine_bootstrap() {
  source "$REPO_ROOT/lib/evidence.sh"
  effective_config_sha256() { printf '%064d\n' "${TEST_CONFIG:-1}"; }
  module_plan_sha256() { printf '%064d\n' 2; }
  evidence_hardware_fingerprint() { echo deferred:container; }
}
repo_commit() { printf '%040d\n' 1; }
effective_config_sha256() { printf '%064d\n' "${TEST_CONFIG:-1}"; }
module_plan_sha256() { printf '%064d\n' 2; }
evidence_hardware_fingerprint() { echo deferred:container; }
baseline_fingerprint() { echo deferred:container; }
runtime_is_baremetal() { [[ "${TEST_BAREMETAL:-false}" == true ]]; }
is_true() { [[ "$1" == true ]]; }
MOCK
cat >> "$REPO_ROOT/lib/backup_runtime.sh" <<'MOCK'
backup_runtime_validate_local_target() { [[ "$1" == "$BACKUP_REPOSITORY" ]]; }
backup_runtime_export_libvirt() { echo 'Unexpected automatic libvirt export' >&2; exit 99; }
MOCK
cat > "$tmp/bin/sudo" <<'MOCK'
#!/usr/bin/env bash
[[ "${1:-}" != -n ]] || shift
if [[ "$1" == du && "$*" == *'/etc /boot'* ]]; then echo '4096 total'; exit; fi
if [[ "$1" == tar ]]; then
  if [[ "${TEST_MUTATE_LOCAL_CONFIG:-false}" == true ]]; then
    printf '# edited during backup\n' >> "$REPO_ROOT/config/local.conf"
  fi
  # Run the script's real tar arguments against a fixture root instead of /.
  shift
  args=()
  while (($#)); do
    case "$1" in
      -C) args+=(-C "$TEST_SYSROOT"); shift ;;
      --xattrs|--acls|--selinux) ;;
      *) args+=("$1") ;;
    esac
    shift
  done
  exec tar "${args[@]}"
fi
exec "$@"
MOCK
cat > "$tmp/bin/xdg-user-dir" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$HOME/.config"
MOCK
cat > "$tmp/bin/rpm" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
git -C "$REPO_ROOT" init -q
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/backup_runtime.sh"
backup_engine_env "$BACKUP_REPOSITORY"
backup_engine_init >/dev/null
bash "$REPO_ROOT/scripts/backup/backup-now.sh" --staging-root "$tmp/staging"
marker="$STATE_ROOT/last-full-backup.ok"
backup_runtime_validate_full_marker "$marker"
archive="$(evidence_marker_value "$marker" archive)"
snapshot="$(evidence_marker_value "$marker" snapshot)"
# The Git-ignored overlay is recoverable even when this checkout is outside
# every user-data root. Restore the actual archive bytes and verify its digest.
mkdir -p "$tmp/restored-overlay"
(cd "$tmp/restored-overlay" && borg extract "::$archive")
restored_overlay="$(find "$tmp/restored-overlay" -path '*/inventory/local.conf' -print -quit)"
[[ -n "$restored_overlay" ]]
cmp "$REPO_ROOT/config/local.conf" "$restored_overlay"
(cd "$(dirname "$restored_overlay")" && sha256sum --check local.conf.sha256)
manifest="$(backup_runtime_recovery_manifest "$archive")"
[[ "$(jq -r '.include_vms' <<<"$manifest")" == false ]]
[[ "$(jq -r '.vm_count' <<<"$manifest")" == 0 ]]
[[ "$(jq -c '.vm_names' <<<"$manifest")" == '[]' ]]
[[ "$(jq -r '.include_vms' <<<"$manifest")" == false ]]
if borg list "::$archive" | grep -Fq 'manual-domain.xml'; then
  echo 'Manual libvirt domain XML was archived by Borg' >&2
  exit 1
fi
backup_runtime_full_vm_coverage_valid "$marker"
# The VM-export policy cannot be enabled, even if a local override is set.
for flag in BACKUP_VM_DISKS BACKUP_LIBVIRT_METADATA BACKUP_VM_CLOUD_INIT_METADATA; do
  if env "$flag=true" bash "$REPO_ROOT/scripts/backup/backup-now.sh" --staging-root "$tmp/rejected-$flag" > "$tmp/rejected-$flag.log" 2>&1; then
    echo "Owner-managed VM policy bypassed: $flag" >&2; exit 1
  fi
  grep -Fq 'VM backup/export is manual-only' "$tmp/rejected-$flag.log"
done
# Invalid/legacy manifests must not earn a current host-only certificate.
coverage="$tmp/vm-coverage.ok"
printf 'include_vms=true\nvm_count=1\nvm_names_sha256=%s\n' "$(printf '[\"demo\"]' | sha256sum | awk '{print $1}')" > "$coverage"
if backup_runtime_full_vm_coverage_valid "$coverage"; then
  echo 'Legacy VM-inclusive backup incorrectly certified' >&2; exit 1
fi
# A newer daily archive never becomes an OS recovery base.
read -r daily _ < <(backup_engine_create daily -- "$HOME/.config")
read -r selected selected_id < <(backup_engine_latest full)
[[ "$selected" == "$archive" && "$selected_id" == "$snapshot" && "$daily" != "$selected" ]]
# A real archive written by a warning must stay outside the recovery namespace.
real_borg="$(command -v borg)"
borg() {
  if [[ "$1" == create ]]; then
    "$real_borg" "$@" || return $?
    return 1
  fi
  "$real_borg" "$@"
}
rc=0
out="$(backup_engine_create full --comment "$manifest" -- "$HOME/.config")" || rc=$?
[[ "$rc" == 1 && -z "$out" ]]
read -r selected selected_id < <(backup_engine_latest full)
[[ "$selected" == "$archive" && "$selected_id" == "$snapshot" ]]
[[ -n "$("$real_borg" list --glob-archives 'fgc-pending-full-*' --short)" ]]
unset -f borg
read -r selected _ < <(backup_engine_latest '')
[[ "$selected" != fgc-pending-* ]]
cp "$marker" "$tmp/good-marker"
sed -i 's/^integrity_check=PASS/integrity_check=FAIL/' "$marker"
if backup_runtime_validate_full_marker "$marker"; then echo 'Failed integrity accepted' >&2; exit 1; fi
cp "$tmp/good-marker" "$marker"
if TEST_CONFIG=3 backup_runtime_validate_full_marker "$marker"; then echo 'Stale config accepted' >&2; exit 1; fi
sed -i "s|^repository=.*|repository=$tmp/wrong-repository|" "$marker"
if backup_runtime_validate_full_marker "$marker"; then echo 'Different repository accepted' >&2; exit 1; fi
cp "$tmp/good-marker" "$marker"
"$real_borg" delete "::$archive"
if backup_runtime_validate_full_marker "$marker"; then echo 'Deleted exact archive accepted' >&2; exit 1; fi
if backup_runtime_recovery_manifest "$daily"; then echo 'Daily recovery manifest accepted' >&2; exit 1; fi
read -r legacy _ < <(backup_engine_create full -- "$HOME/.config")
if backup_runtime_recovery_manifest "$legacy"; then echo 'Legacy archive certified without manifest' >&2; exit 1; fi

# Warnings/errors must return no archive identity to any success-marker caller.
borg() { printf '{"archive":{"name":"ignored","id":"%064d"}}\n' 1; return "$TEST_BORG_RC"; }
for TEST_BORG_RC in 1 2; do
  rc=0
  output="$(backup_engine_create full -- "$HOME/.config")" || rc=$?
  [[ "$rc" == "$TEST_BORG_RC" && -z "$output" ]]
done
unset -f borg
# Manual-only means the old flag must be rejected before any Borg or VM work.
if bash "$REPO_ROOT/scripts/backup/backup-now.sh" --include-vms > "$tmp/unsupported-flag.log" 2>&1; then
  echo 'Deprecated VM automatic backup flag unexpectedly succeeded' >&2; exit 1
fi
grep -Fq 'owner-managed' "$tmp/unsupported-flag.log"
# Editing the Git-ignored overlay while an archive is being captured must
# refuse a new certificate, even when the restored archive is byte-correct.
cp "$marker" "$tmp/marker-before-edit"
cp "$REPO_ROOT/config/local.conf" "$tmp/local-before-edit"
rc=0
TEST_MUTATE_LOCAL_CONFIG=true bash "$REPO_ROOT/scripts/backup/backup-now.sh" --staging-root "$tmp/edited-staging" > "$tmp/edited.log" 2>&1 || rc=$?
[[ "$rc" == 40 ]]
grep -Fq 'Local configuration restore proof failed' "$tmp/edited.log"
cmp "$marker" "$tmp/marker-before-edit"
cp "$tmp/local-before-edit" "$REPO_ROOT/config/local.conf"

# Bare metal with /data not proven to be the second NVMe: refused before Borg.
rc=0
TEST_BAREMETAL=true bash "$REPO_ROOT/scripts/backup/backup-now.sh" --staging-root "$tmp/data-refused" > "$tmp/data-refused.log" 2>&1 || rc=$?
[[ "$rc" == 20 ]] || { cat "$tmp/data-refused.log" >&2; echo "unproven /data accepted (rc=$rc)" >&2; exit 1; }
grep -Fq '/data is not the dedicated EXT4 second T705' "$tmp/data-refused.log"

# Bare metal with a valid /data: Documents and Projets are archived, Jeux and
# ISO are not, and the /etc snapshot inside the archive has no libvirt XML.
TEST_BAREMETAL=true TEST_DATA_MOUNT=valid bash "$REPO_ROOT/scripts/backup/backup-now.sh" --staging-root "$tmp/staging-data"
data_archive="$(evidence_marker_value "$marker" archive)"
borg list --short "::$data_archive" > "$tmp/data-members"
for kept in Documents/facture.pdf Projets/main.py; do
  grep -Fq "data/$kept" "$tmp/data-members" || { echo "full backup misses /data/$kept" >&2; exit 1; }
done
if grep -Eq 'data/(Jeux|ISO)/' "$tmp/data-members"; then echo 'full backup archived Jeux or ISO' >&2; exit 1; fi
mkdir "$tmp/system-config"
(cd "$tmp/system-config" && borg extract "::$data_archive" --pattern='+**/fedora-system-config.tar.gz' --pattern='-**')
system_tar="$(find "$tmp/system-config" -name fedora-system-config.tar.gz -print -quit)"
tar -tzf "$system_tar" > "$tmp/system-members"
grep -Fxq 'etc/hostname' "$tmp/system-members"
grep -Fxq 'boot/vmlinuz-fixture' "$tmp/system-members"
if grep -Fq 'etc/libvirt' "$tmp/system-members"; then echo 'libvirt domain XML leaked into the /etc snapshot' >&2; exit 1; fi
echo 'Backup certification behavior: PASS'

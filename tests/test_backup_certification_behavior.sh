#!/usr/bin/env bash
# Real full archive creation and exact-archive certification in a disposable
# fixture. The platform/inventory commands are simulated, never Gate 3 proof.
# shellcheck disable=SC2016,SC2034,SC1090
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home" BORG_BASE_DIR="$tmp/borg-base"
export BACKUP_REPOSITORY="$tmp/borg" STATE_ROOT="$tmp/state"
export REPO_ROOT="$tmp/fixture"
mkdir -p "$HOME/.config" "$STATE_ROOT" "$REPO_ROOT/lib" "$REPO_ROOT/scripts/backup" "$tmp/bin"
cp "$ROOT/lib/backup_runtime.sh" "$REPO_ROOT/lib/"
cp "$ROOT/lib/evidence.sh" "$REPO_ROOT/lib/"
cp "$ROOT/scripts/backup/backup-now.sh" "$REPO_ROOT/scripts/backup/"
printf 'settings\n' > "$HOME/.config/settings"
cat > "$REPO_ROOT/lib/install_lock.sh" <<'MOCK'
install_lock_acquire() { return 0; }
MOCK
cat > "$REPO_ROOT/lib/persistent_data.sh" <<'MOCK'
# No real persistent-data mount in this fixture.
MOCK
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
runtime_is_baremetal() { return 1; }
is_true() { [[ "$1" == true ]]; }
MOCK
cat >> "$REPO_ROOT/lib/backup_runtime.sh" <<'MOCK'
backup_runtime_validate_local_target() { [[ "$1" == "$BACKUP_REPOSITORY" ]]; }
backup_runtime_capture_inventory() { mkdir -p "$1"; printf 'inventory\n' > "$1/metadata.txt"; }
backup_runtime_export_libvirt() { mkdir -p "$1/domains"; }
MOCK
cat > "$tmp/bin/sudo" <<'MOCK'
#!/usr/bin/env bash
if [[ "$1" == du && "$*" == *'/etc /boot'* ]]; then echo '4096 total'; exit; fi
if [[ "$1" == tar ]]; then
  while (($#)); do
    if [[ "$1" == -czf ]]; then printf 'fixture system configuration\n' > "$2"; exit; fi
    shift
  done
fi
exec "$@"
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
manifest="$(backup_runtime_recovery_manifest "$archive")"
[[ "$(jq -r '.include_vms' <<<"$manifest")" == false ]]
[[ "$(jq -r '.vm_count' <<<"$manifest")" == 0 ]]
# A newer daily archive never becomes an OS recovery base.
read -r daily _ < <(backup_engine_create daily -- "$HOME/.config")
read -r selected selected_id < <(backup_engine_latest full)
[[ "$selected" == "$archive" && "$selected_id" == "$snapshot" && "$daily" != "$selected" ]]
cp "$marker" "$tmp/good-marker"
sed -i 's/^integrity_check=PASS/integrity_check=FAIL/' "$marker"
if backup_runtime_validate_full_marker "$marker"; then echo 'Failed integrity accepted' >&2; exit 1; fi
cp "$tmp/good-marker" "$marker"
if TEST_CONFIG=3 backup_runtime_validate_full_marker "$marker"; then echo 'Stale config accepted' >&2; exit 1; fi
sed -i "s|^repository=.*|repository=$tmp/wrong-repository|" "$marker"
if backup_runtime_validate_full_marker "$marker"; then echo 'Different repository accepted' >&2; exit 1; fi
cp "$tmp/good-marker" "$marker"
borg delete "::$archive"
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
# Capacity failure must happen before any VM conversion. Exercise the real
# backup-now entrypoint with its real measurement/capacity helpers.
cat > "$tmp/bin/virsh" <<'MOCK'
#!/usr/bin/env bash
case "$3" in
  list) echo demo ;;
  domstate) echo 'shut off' ;;
  dumpxml) echo '<domain/>' ;;
  *) exit 1 ;;
esac
MOCK
cat > "$tmp/bin/qemu-img" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
  check) exit 0 ;;
  measure) echo '{"required":9000000000000000000}' ;;
  convert) touch "$TEST_CONVERT_CALLED"; exit 1 ;;
  *) exit 1 ;;
esac
MOCK
cat > "$REPO_ROOT/scripts/backup/vm-backup-plan.py" <<'MOCK'
print('{"disks":[{"source":"/fixture/disk.qcow2","target":"vda"}],"state_paths":[]}')
MOCK
chmod +x "$tmp/bin/"*
export TEST_CONVERT_CALLED="$tmp/conversion-called"
rc=0
bash "$REPO_ROOT/scripts/backup/backup-now.sh" --include-vms --staging-root "$tmp/vm-staging" > "$tmp/capacity.log" 2>&1 || rc=$?
[[ "$rc" == 40 && ! -e "$TEST_CONVERT_CALLED" ]]
grep -Fq 'Insufficient staging capacity for VM demo disk vda' "$tmp/capacity.log"
echo 'Backup certification behavior: PASS'

#!/usr/bin/env bash
# Real ./control.sh and ./menu.sh runs in a copy of the repository whose
# engines are replaced by recorders: every public command reaches the right
# engine with the right arguments, invalid commands reach none. Also runs the
# dashboard, its proof states and the transient-artifact retention.
# shellcheck disable=SC2016,SC2329
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "control center behavior: FAIL: $*" >&2; exit 1; }

fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
git -C "$fixture" init -q
git -C "$fixture" -c user.name=t -c user.email=t@t add -A
git -C "$fixture" -c user.name=t -c user.email=t@t commit -qm fixture
export CC_CALLS="$tmp/calls" NO_COLOR=1
cat > "$tmp/bin/sudo" <<'SH'
#!/usr/bin/env bash
exec "$@"
SH
chmod +x "$tmp/bin/sudo"
export PATH="$tmp/bin:$PATH"

engines=(
  install.sh prepare-preapply-backup.sh diagnostic.sh
  scripts/maintenance/update-system.sh scripts/maintenance/upgrade-fedora.sh
  scripts/backup/backup-now.sh scripts/backup/daily-user-backup.sh scripts/backup/restore.sh
  scripts/backup/disaster-recovery.sh scripts/collect-boot-failure.sh
  scripts/kernel/kernel-lifecycle.sh scripts/kernel/rollback-to-fedora.sh
  scripts/kvm/kvm_network_guard.sh scripts/kvm/runtime_certification.sh
  scripts/kvm/configure_nautilus_vm_access.sh scripts/kvm/create_rocky_devops_vm.sh
  scripts/performance/profile.sh scripts/performance/nvme-scheduler-benchmark.sh
  scripts/performance/game-performance.sh scripts/release/seal-golden-archive.sh
  scripts/validation/status.sh scripts/validation/live-usb.sh scripts/validation/import-proof.sh
  scripts/validation/export-proof.sh scripts/validation/gate3-baremetal.sh
  diagnostics/baseline-doctor diagnostics/kernel-doctor diagnostics/graphics-doctor
  diagnostics/storage-doctor diagnostics/display-doctor diagnostics/gnome-doctor
  diagnostics/applications-doctor diagnostics/media-doctor diagnostics/virtualization-doctor
  diagnostics/backup-doctor diagnostics/final-certification diagnostics/data-storage-doctor
  diagnostics/gaming-doctor diagnostics/polish-doctor diagnostics/remote-doctor
  diagnostics/performance-doctor diagnostics/sched-ext-doctor diagnostics/zram-doctor
  diagnostics/nvme-scheduler-doctor diagnostics/frametime-doctor
)
for engine in "${engines[@]}"; do
  [[ -f "$fixture/$engine" ]] || fail "routed engine missing from the repository: $engine"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "%s $*" >> "$CC_CALLS"\n' "$engine" > "$fixture/$engine"
  chmod +x "$fixture/$engine"
done

# route "COMMAND ARGS" "ENGINE ARGS": exactly one engine call, with these arguments.
route() {
  local command="$1" expected="$2" rc=0
  : > "$CC_CALLS"
  read -r -a args <<<"$command"
  "$fixture/control.sh" "${args[@]}" > "$tmp/out" 2>&1 || rc=$?
  [[ "$rc" == 0 ]] || { cat "$tmp/out" >&2; fail "./control.sh $command exited $rc"; }
  [[ "$(sed 's/ *$//' "$CC_CALLS")" == "${expected% }" ]] || fail "./control.sh $command called '$(paste -sd'|' "$CC_CALLS")', expected '$expected'"
}
refused() {
  local rc=0
  : > "$CC_CALLS"
  "$fixture/control.sh" "$@" > "$tmp/out" 2>&1 < /dev/null || rc=$?
  [[ "$rc" == 2 ]] || fail "./control.sh $* exited $rc, expected usage error 2"
  [[ ! -s "$CC_CALLS" ]] || fail "./control.sh $* still ran $(cat "$CC_CALLS")"
}

route 'install prepare-tools' 'diagnostics/baseline-doctor prepare-tools'
route 'install dry-run' 'install.sh --dry-run'
route 'install backup' 'prepare-preapply-backup.sh '
route 'install apply' 'install.sh --apply'
route 'update check' 'scripts/maintenance/update-system.sh --check'
route 'update all' 'scripts/maintenance/update-system.sh --apply'
route 'update dnf' 'scripts/maintenance/update-system.sh --dnf-only'
route 'update flatpak' 'scripts/maintenance/update-system.sh --flatpak-only'
route 'update firmware' 'scripts/maintenance/update-system.sh --firmware-check'
route 'update reboot' 'scripts/maintenance/update-system.sh --offline-reboot'
route 'update finalize' 'scripts/maintenance/update-system.sh --finalize'
route 'update status' 'scripts/maintenance/update-system.sh --offline-status'
route 'update log' 'scripts/maintenance/update-system.sh --offline-log'
route 'upgrade' 'scripts/maintenance/upgrade-fedora.sh plan'
route 'upgrade download' 'scripts/maintenance/upgrade-fedora.sh download'
route 'backup now' 'scripts/backup/backup-now.sh '
route 'backup daily' 'scripts/backup/daily-user-backup.sh '
route 'backup list' 'scripts/backup/restore.sh list'
route 'backup check' 'diagnostics/backup-doctor '
route 'backup deep' 'diagnostics/backup-doctor --deep'
route 'backup restore' 'scripts/backup/restore.sh restore latest'
route 'backup restore fgc-full-20261001' 'scripts/backup/restore.sh restore fgc-full-20261001'
route 'backup dr-plan' 'scripts/backup/disaster-recovery.sh '
route 'backup prune' 'scripts/backup/backup-now.sh --prune'
route 'doctor all' 'diagnostic.sh '
route 'doctor baseline' 'diagnostics/baseline-doctor status'
for domain in kernel graphics storage display gnome media backup; do
  route "doctor $domain" "diagnostics/$domain-doctor "
done
route 'doctor apps' 'diagnostics/applications-doctor '
route 'doctor kvm' 'diagnostics/virtualization-doctor '
for domain in data gaming polish remote; do
  expected="diagnostics/$domain-doctor "
  [[ "$domain" != data ]] || expected='diagnostics/data-storage-doctor '
  route "doctor $domain" "$expected"
done
route 'kernel doctor' 'diagnostics/kernel-doctor '
for action in install-latest prune rollback fallback refresh-fallback; do
  route "kernel $action" "scripts/kernel/kernel-lifecycle.sh $action"
done
route 'kernel rollback-fedora' 'scripts/kernel/rollback-to-fedora.sh '
route 'kvm status' 'diagnostics/virtualization-doctor '
route 'kvm guard-check' 'scripts/kvm/kvm_network_guard.sh check'
route 'kvm guard-reconcile' 'scripts/kvm/kvm_network_guard.sh reconcile'
route 'kvm certify' 'scripts/kvm/runtime_certification.sh '
route 'kvm nautilus-refresh' 'scripts/kvm/configure_nautilus_vm_access.sh refresh'
route 'kvm create-rocky --cloud-image /data/libvirt/iso/rocky.qcow2 --rocky-key-file /tmp/key' \
  'scripts/kvm/create_rocky_devops_vm.sh --cloud-image /data/libvirt/iso/rocky.qcow2 --rocky-key-file /tmp/key'
route 'perf status' 'diagnostics/performance-doctor '
for profile in balanced performance powersave; do route "perf $profile" "scripts/performance/profile.sh $profile"; done
route 'perf sched-status' 'diagnostics/sched-ext-doctor '
route 'perf sched-smoke' 'diagnostics/sched-ext-doctor --smoke'
route 'perf zram' 'diagnostics/zram-doctor '
route 'perf nvme' 'diagnostics/nvme-scheduler-doctor '
route 'perf nvme-benchmark' 'scripts/performance/nvme-scheduler-benchmark.sh '
route 'perf frametime run.csv' 'diagnostics/frametime-doctor run.csv'
route 'perf game steam -applaunch 42' 'scripts/performance/game-performance.sh steam -applaunch 42'
route 'cert status' 'diagnostics/final-certification status'
route 'cert record-suspend' 'diagnostics/final-certification record-suspend'
route 'cert certify' 'diagnostics/final-certification certify'
route 'cert baseline-status' 'diagnostics/baseline-doctor status'
route 'cert baseline-certify' 'diagnostics/baseline-doctor certify'
route 'cert archive /mnt/archive payload.iso payload.qcow2' 'scripts/release/seal-golden-archive.sh /mnt/archive payload.iso payload.qcow2'
route 'logs boot-failure' 'scripts/collect-boot-failure.sh '
route 'validate' 'scripts/validation/status.sh '
route 'validate live' 'scripts/validation/live-usb.sh plan'
route 'validate live run' 'scripts/validation/live-usb.sh run'
route 'validate import proof.json' 'scripts/validation/import-proof.sh proof.json'
route 'validate export live /mnt/usb' 'scripts/validation/export-proof.sh 2 /mnt/usb'
route 'validate gate3 certify' 'scripts/validation/gate3-baremetal.sh certify'
route 'remote' 'diagnostics/remote-doctor '
route 'remote info' 'diagnostics/remote-doctor --info'

# The historical entrypoint is the same Control Center.
: > "$CC_CALLS"
"$fixture/menu.sh" install dry-run > /dev/null
[[ "$(cat "$CC_CALLS")" == 'install.sh --dry-run' ]] || fail 'menu.sh is not an alias of control.sh'

# Unknown or incomplete commands are usage errors that run nothing.
refused bogus
for domain in install update backup doctor kernel kvm cert logs; do refused "$domain" bogus; done
refused perf bogus
refused perf frametime
refused perf game
refused cert archive /mnt/archive
refused validate bogus
refused validate import
refused validate export live
refused remote bogus
refused kvm create-windows
refused

# Read-only dashboard, outside Fedora and bare metal.
"$fixture/control.sh" status > "$tmp/status" || fail 'status dashboard failed'
for line in Projet Runtime Kernel Data Gaming Performance; do
  grep -q "$line" "$tmp/status" || fail "dashboard misses its $line line"
done
if grep -q $'\e\[' "$tmp/status"; then fail 'NO_COLOR=1 still prints ANSI colours'; fi

# Proof states shown by the dashboard follow the current identity, not marker presence.
(
  REPO_ROOT="$fixture"
  source "$fixture/lib/constants.sh"
  source "$fixture/lib/control_center.sh"
  STATE_ROOT="$tmp/state"
  mkdir -p "$STATE_ROOT/final"
  workstation_runtime_fingerprint() { echo "${T_FINGERPRINT:-fp1}"; }
  effective_config_sha256() { echo "${T_CONFIG:-cfg1}"; }
  module_plan_sha256() { echo plan1; }
  repo_commit() { echo "${T_COMMIT:-c1}"; }
  [[ "$(cc_cert_state)" == PENDING ]] || fail 'missing certificate not PENDING'
  printf 'fingerprint=fp1\neffective_config_sha256=cfg1\nmodule_plan_sha256=plan1\nperformance_contract=PASS\n' > "$STATE_ROOT/final/certified.ok"
  [[ "$(cc_cert_state)" == VALID ]] || fail 'current certificate not VALID'
  [[ "$(T_FINGERPRINT=fp2 cc_cert_state)" == STALE ]] || fail 'certificate for another runtime not STALE'
  [[ "$(T_CONFIG=cfg2 cc_cert_state)" == STALE ]] || fail 'certificate for another config not STALE'
  sed -i 's/performance_contract=PASS/performance_contract=FAIL/' "$STATE_ROOT/final/certified.ok"
  [[ "$(cc_cert_state)" == STALE ]] || fail 'certificate with a failed performance contract not STALE'
  [[ "$(cc_backup_state)" == PENDING ]] || fail 'missing backup not PENDING'
  printf 'commit=c1\nutc=2026-10-01T00:00:00Z\n' > "$STATE_ROOT/last-full-backup.ok"
  [[ "$(cc_backup_state)" == PASS ]] || fail 'current backup not PASS'
  [[ "$(T_COMMIT=c2 cc_backup_state)" == WARN ]] || fail 'backup from another commit not WARN'
) || exit 1

# Retention removes only old logs and reports; state/ and releases are kept.
mkdir -p "$fixture/logs/old-run" "$fixture/logs/recent-run" "$fixture/reports" "$fixture/state/releases"
touch "$fixture/reports/old.txt" "$fixture/reports/recent.txt" "$fixture/state/old.ok" "$fixture/state/releases/old.tar"
touch -d '200 days ago' "$fixture/logs/old-run" "$fixture/reports/old.txt" "$fixture/state/old.ok" "$fixture/state/releases/old.tar" "$fixture/state/releases" "$fixture/state"
"$fixture/control.sh" logs retention > "$tmp/retention"
[[ -d "$fixture/logs/old-run" && -f "$fixture/reports/old.txt" ]] || fail 'logs retention (check) deleted files'
grep -q 'Old log runs: 1' "$tmp/retention" || fail 'old log run not reported'
"$fixture/control.sh" logs prune > /dev/null
[[ ! -e "$fixture/logs/old-run" && ! -e "$fixture/reports/old.txt" ]] || fail 'old logs or reports not pruned'
[[ -d "$fixture/logs/recent-run" && -f "$fixture/reports/recent.txt" ]] || fail 'recent logs or reports pruned'
[[ -f "$fixture/state/old.ok" && -f "$fixture/state/releases/old.tar" ]] || fail 'Golden state or release pruned'
sed -i 's/^preserve_state=true$/preserve_state=false/' "$fixture/config/operator-retention.policy"
rc=0; "$fixture/control.sh" logs prune > /dev/null 2>&1 || rc=$?
[[ "$rc" != 0 ]] || fail 'retention ran with a policy that does not preserve state/'

echo 'control center behavior: PASS'

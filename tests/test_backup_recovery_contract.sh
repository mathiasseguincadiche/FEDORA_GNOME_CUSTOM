#!/usr/bin/env bash
# shellcheck disable=SC2016
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for expected in \
  'BACKUP_ENGINE="borg"' \
  'BACKUP_ENCRYPTION="none"' \
  'BACKUP_FAIL_CLOSED="true"' \
  'BACKUP_REQUIRE_EXTERNAL_TARGET="true"' \
  'BACKUP_INTEGRITY_CHECK_REQUIRED="true"' \
  'BACKUP_RESTORE_TEST_REQUIRED="true"' \
  'BACKUP_VM_SHUTDOWN_REQUIRED="true"' \
  'BACKUP_VM_DISKS="false"' \
  'BACKUP_ALLOW_LIVE_QCOW2_COPY="false"' \
  'BACKUP_PRUNE_AUTOMATICALLY="true"' \
  'BACKUP_RETENTION_TIMER_ENABLED="true"' \
  'DAILY_BACKUP_XDG_DIRS="DESKTOP DOCUMENTS PICTURES VIDEOS MUSIC"' \
  'DAILY_BACKUP_EXTRA_PATHS="/data/Projets /data/IA/Openclaw Development .config .mozilla .var/app .local/share"'; do
  grep -Fq "$expected" "$ROOT/config/backup.conf" || { echo "missing backup policy: $expected" >&2; exit 1; }
done
for entry in \
  'backup.inventory|BACKUP|backup.preflight|modules/backup/51_inventory.sh' \
  'backup.repository|BACKUP|backup.inventory|modules/backup/52_repository.sh' \
  'backup.host|BACKUP|backup.repository|modules/backup/53_host_backup.sh' \
  'backup.kvm|BACKUP|backup.host|modules/backup/54_kvm_metadata.sh' \
  'backup.vm|BACKUP|backup.kvm|modules/backup/55_vm_backup.sh' \
  'backup.integrity|BACKUP|backup.vm|modules/backup/56_integrity_retention.sh' \
  'backup.restore|BACKUP|backup.integrity|modules/backup/57_restore.sh' \
  'backup.dr|BACKUP|backup.restore|modules/backup/58_disaster_recovery.sh'; do
  grep -Fq "$entry" "$ROOT/manifests/module-plan.conf" || { echo "missing backup module: $entry" >&2; exit 1; }
done
for file in lib/backup_runtime.sh lib/backup_runtime_bundle.sh lib/persistent_data.sh prepare-preapply-backup.sh scripts/backup/backup-now.sh scripts/backup/daily-user-backup.sh scripts/backup/backup-retention.sh scripts/backup/restore.sh scripts/backup/disaster-recovery.sh diagnostics/backup-doctor; do
  [[ -f "$ROOT/$file" ]] || { echo "missing backup/recovery file: $file" >&2; exit 1; }
done

# Pre-APPLY backup authorization is tied to the entire Golden identity and to a live Borg archive.
grep -Fq 'evidence_require_current_identity' "$ROOT/lib/apply_gate.sh"
grep -Fq 'backup_runtime_validate_preapply_marker' "$ROOT/lib/apply_gate.sh"
grep -Fq 'effective_config_sha256' "$ROOT/prepare-preapply-backup.sh"
grep -Fq 'backup_runtime_identity_payload' "$ROOT/prepare-preapply-backup.sh"
grep -Fq 'module_plan_sha256' "$ROOT/lib/backup_runtime.sh"
grep -Fq 'hardware_fingerprint' "$ROOT/lib/backup_runtime.sh"
grep -Fq 'backup_runtime_validate_preapply_marker' "$ROOT/prepare-preapply-backup.sh"
grep -Fq 'backup_engine_archive_matches "$archive" "$snapshot" preapply' "$ROOT/lib/backup_runtime.sh"
grep -Fq 'restore-canary' "$ROOT/prepare-preapply-backup.sh"
grep -Fq 'backup_engine_check preapply' "$ROOT/prepare-preapply-backup.sh"

# Full and daily backups protect Documents/Projets; ISO and Jeux stay excluded by default.
grep -Fq 'VM exports are owner-managed' "$ROOT/scripts/backup/backup-now.sh"
grep -Fq 'VM backup/export is manual-only' "$ROOT/scripts/backup/backup-now.sh"
grep -Fq 'BACKUP_LIBVIRT_METADATA="false"' "$ROOT/config/backup.conf"
grep -Fq 'BACKUP_VM_CLOUD_INIT_METADATA="false"' "$ROOT/config/backup.conf"
if grep -Fq 'backup_runtime_export_libvirt "$staging/libvirt"' "$ROOT/scripts/backup/backup-now.sh"; then
  echo 'Full backup still captures libvirt metadata' >&2; exit 1
fi
if grep -Fq 'backup_runtime_export_libvirt "$staging/libvirt"' "$ROOT/prepare-preapply-backup.sh"; then
  echo 'Pre-APPLY backup still captures libvirt metadata' >&2; exit 1
fi
if grep -Fq -- '--include-vms' "$ROOT/scripts/maintenance/upgrade-fedora.sh"; then
  echo 'Fedora upgrade still forces VM backups' >&2; exit 1
fi
if grep -Fq -- 'now-with-vms)' "$ROOT/lib/control_center.sh"; then
  echo 'Control Center still exposes VM backups' >&2; exit 1
fi
for file in README.md docs/CONTROL_CENTER.md lib/control_center_presentation.sh; do
  if grep -Fq 'now-with-vms' "$ROOT/$file"; then
    echo "Unsupported automatic VM backup advertised in $file" >&2; exit 1
  fi
done
for p in scripts/backup/backup-now.sh prepare-preapply-backup.sh scripts/backup/daily-user-backup.sh; do
  grep -Fq -- 'libvirt/*' "$ROOT/$p" || {
    echo "Borg path lacks a libvirt exclusion: $p" >&2; exit 1;
  }
done
grep -Fq 'for key in DESKTOP DOCUMENTS PICTURES VIDEOS MUSIC' "$ROOT/scripts/backup/backup-now.sh"
grep -Fq -- '--exclude "*.qcow2"' "$ROOT/scripts/backup/daily-user-backup.sh"
if grep -Fq 'qemu-img convert' "$ROOT/scripts/backup/backup-now.sh"; then
  echo 'VM conversion must never run inside the Borg script' >&2
  exit 1
fi
if [[ -e "$ROOT/scripts/backup/vm-backup-plan.py" ]]; then
  echo 'Obsolete automatic VM backup plan still exists' >&2
  exit 1
fi
grep -Fq 'source "$REPO_ROOT/lib/persistent_data.sh"' "$ROOT/scripts/backup/backup-now.sh"
grep -Fq 'persistent_data_documents' "$ROOT/scripts/backup/backup-now.sh"
grep -Fq 'persistent_data_projects' "$ROOT/scripts/backup/backup-now.sh"
grep -Fq 'Refusing full backup: /data is not the dedicated EXT4 second T705.' "$ROOT/scripts/backup/backup-now.sh"
grep -Fq 'Refusing in-place/live restore target' "$ROOT/scripts/backup/restore.sh"
grep -Fq 'xdg-user-dir' "$ROOT/scripts/backup/daily-user-backup.sh"
grep -Fq 'DAILY_BACKUP_XDG_DIRS' "$ROOT/scripts/backup/daily-user-backup.sh"
grep -Fq 'DAILY_BACKUP_EXTRA_PATHS' "$ROOT/scripts/backup/daily-user-backup.sh"
grep -Fq '/data/Documents|/data/Projets' "$ROOT/scripts/backup/daily-user-backup.sh"
grep -Fq 'Refusing persistent-data backup: /data is not the dedicated EXT4 second T705.' "$ROOT/scripts/backup/daily-user-backup.sh"
grep -Fq 'source_count=' "$ROOT/scripts/backup/daily-user-backup.sh"
if grep -Fq 'Documents Desktop Pictures Videos Music' "$ROOT/scripts/backup/daily-user-backup.sh"; then
  echo 'daily backup still contains locale-dependent English user-directory defaults' >&2
  exit 1
fi
if grep -Fq '/data/ISO' "$ROOT/config/backup.conf" && grep -Fq '/data/ISO' "$ROOT/scripts/backup/daily-user-backup.sh"; then
  echo 'ISO library must not enter the default daily backup source allowlist' >&2
  exit 1
fi
if grep -Fq '/data/Jeux' "$ROOT/config/backup.conf" || grep -Fq '/data/Jeux' "$ROOT/scripts/backup/daily-user-backup.sh" || grep -Fq 'persistent_data_games' "$ROOT/scripts/backup/backup-now.sh"; then
  echo 'Games library must remain outside automatic daily/full backup sources by default' >&2
  exit 1
fi
if grep -RInE '(mkfs\.|wipefs|parted[[:space:]]|sgdisk[[:space:]]|setenforce[[:space:]]+0)' "$ROOT/scripts/backup" "$ROOT/modules/backup"; then
  echo 'forbidden destructive backup/recovery command found' >&2
  exit 1
fi
grep -Fq 'for kind in full daily; do' "$ROOT/scripts/backup/backup-retention.sh"
grep -Fq 'FEDORA_GNOME_CUSTOM_RUNTIME_ROOT' "$ROOT/scripts/backup/daily-user-backup.sh"
grep -Fq 'MANIFEST.sha256' "$ROOT/lib/backup_runtime_bundle.sh"

# Even the privileged /etc system snapshot must exclude libvirt's domain XML.
for script in scripts/backup/backup-now.sh prepare-preapply-backup.sh; do
  grep -Fq -- '--exclude=etc/libvirt' "$ROOT/$script" || {
    echo "system-config tar still includes VM definitions: $script" >&2; exit 1;
  }
done
# Check GNU tar's intended exclusion with a disposable /etc tree; never read
# the host's real /etc/libvirt and never create real VM state.
tmp_tar="$(mktemp -d)"
mkdir -p "$tmp_tar/etc/libvirt/qemu" "$tmp_tar/archive"
printf 'host config\n' > "$tmp_tar/etc/hostname"
printf 'private domain XML\n' > "$tmp_tar/etc/libvirt/qemu/owner-managed.xml"
tar -C "$tmp_tar" --exclude=etc/libvirt --exclude='etc/libvirt/*' -czf "$tmp_tar/archive/host.tgz" etc
tar -tzf "$tmp_tar/archive/host.tgz" > "$tmp_tar/archive/members.txt"
grep -Fqx 'etc/hostname' "$tmp_tar/archive/members.txt"
if grep -Fq 'etc/libvirt' "$tmp_tar/archive/members.txt"; then
  echo 'VM metadata leaked into simulated HOST tar' >&2
  rm -rf "$tmp_tar"
  exit 1
fi
rm -rf "$tmp_tar"

echo 'backup/recovery contract: PASS'

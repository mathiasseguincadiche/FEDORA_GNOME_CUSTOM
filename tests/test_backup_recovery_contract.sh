#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for expected in \
  'BACKUP_ENGINE="restic"' \
  'BACKUP_FAIL_CLOSED="true"' \
  'BACKUP_REQUIRE_EXTERNAL_TARGET="true"' \
  'BACKUP_ENCRYPTION_REQUIRED="true"' \
  'BACKUP_INTEGRITY_CHECK_REQUIRED="true"' \
  'BACKUP_RESTORE_TEST_REQUIRED="true"' \
  'BACKUP_VM_SHUTDOWN_REQUIRED="true"' \
  'BACKUP_ALLOW_LIVE_QCOW2_COPY="false"' \
  'BACKUP_PRUNE_AUTOMATICALLY="false"' \
  'DAILY_BACKUP_XDG_DIRS="DESKTOP DOCUMENTS PICTURES VIDEOS MUSIC"' \
  'DAILY_BACKUP_EXTRA_PATHS="Projects Development .config .ssh .gnupg"'; do
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
for file in lib/backup_runtime.sh prepare-preapply-backup.sh scripts/backup/backup-now.sh scripts/backup/daily-user-backup.sh scripts/backup/restore.sh scripts/backup/disaster-recovery.sh diagnostics/backup-doctor; do
  [[ -f "$ROOT/$file" ]] || { echo "missing backup/recovery file: $file" >&2; exit 1; }
done
grep -Fq 'marker_commit' "$ROOT/lib/apply_gate.sh"
grep -Fq 'restore-canary' "$ROOT/prepare-preapply-backup.sh"
grep -Fq 'restic check' "$ROOT/prepare-preapply-backup.sh"
grep -Fq 'qemu-img convert' "$ROOT/scripts/backup/backup-now.sh"
grep -Fq 'Refusing in-place/live restore target' "$ROOT/scripts/backup/restore.sh"
grep -Fq 'xdg-user-dir' "$ROOT/scripts/backup/daily-user-backup.sh"
grep -Fq 'DAILY_BACKUP_XDG_DIRS' "$ROOT/scripts/backup/daily-user-backup.sh"
grep -Fq 'DAILY_BACKUP_EXTRA_PATHS' "$ROOT/scripts/backup/daily-user-backup.sh"
grep -Fq 'source_count=' "$ROOT/scripts/backup/daily-user-backup.sh"
if grep -Fq 'Documents Desktop Pictures Videos Music' "$ROOT/scripts/backup/daily-user-backup.sh"; then
  echo 'daily backup still contains locale-dependent English user-directory defaults' >&2
  exit 1
fi
if grep -RInE '(mkfs\.|wipefs|parted[[:space:]]|sgdisk[[:space:]]|setenforce[[:space:]]+0)' "$ROOT/scripts/backup" "$ROOT/modules/backup"; then
  echo 'forbidden destructive backup/recovery command found' >&2
  exit 1
fi
echo 'backup/recovery contract: PASS'

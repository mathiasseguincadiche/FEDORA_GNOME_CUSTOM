#!/usr/bin/env bash
# Backup specification: the Golden policy values, the module order and the
# commands that must never appear. Behaviour is exercised with fake or real
# Borg by test_daily_backup_sources_behavior.sh,
# test_backup_certification_behavior.sh and test_borg_roundtrip.sh.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "backup/recovery contract: FAIL: $*" >&2; exit 1; }

for expected in \
  'BACKUP_ENGINE="borg"' \
  'BACKUP_ENCRYPTION="none"' \
  'BACKUP_FAIL_CLOSED="true"' \
  'BACKUP_REQUIRE_EXTERNAL_TARGET="true"' \
  'BACKUP_INTEGRITY_CHECK_REQUIRED="true"' \
  'BACKUP_RESTORE_TEST_REQUIRED="true"' \
  'BACKUP_VM_SHUTDOWN_REQUIRED="true"' \
  'BACKUP_VM_DISKS="false"' \
  'BACKUP_LIBVIRT_METADATA="false"' \
  'BACKUP_VM_CLOUD_INIT_METADATA="false"' \
  'BACKUP_ALLOW_LIVE_QCOW2_COPY="false"' \
  'BACKUP_PRUNE_AUTOMATICALLY="true"' \
  'BACKUP_RETENTION_TIMER_ENABLED="true"' \
  'DAILY_BACKUP_XDG_DIRS="DESKTOP DOCUMENTS PICTURES VIDEOS MUSIC"' \
  'DAILY_BACKUP_EXTRA_PATHS="/data/Projets /data/IA/Openclaw Development .config .mozilla .var/app .local/share"'; do
  grep -Fxq "$expected" "$ROOT/config/backup.conf" || fail "backup policy missing: $expected"
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
  grep -Fq "$entry" "$ROOT/manifests/module-plan.conf" || fail "backup module missing: $entry"
done

# VM exports stay manual: no automatic VM backup route or flag.
if grep -Fq 'now-with-vms' "$ROOT/lib/control_center.sh" "$ROOT/lib/control_center_presentation.sh"; then
  fail 'the Control Center exposes automatic VM backups'
fi
if grep -Fq -- '--include-vms' "$ROOT/scripts/maintenance/upgrade-fedora.sh"; then
  fail 'the Fedora upgrade forces VM backups'
fi

# Backup and recovery never format, wipe, repartition, convert VM disks or relax SELinux.
if grep -RInE '(mkfs\.|wipefs|parted[[:space:]]|sgdisk[[:space:]]|setenforce[[:space:]]+0|qemu-img[[:space:]]+convert)' \
  "$ROOT/scripts/backup" "$ROOT/modules/backup" "$ROOT/prepare-preapply-backup.sh"; then
  fail 'forbidden destructive backup/recovery command found'
fi

echo 'backup/recovery contract: PASS'

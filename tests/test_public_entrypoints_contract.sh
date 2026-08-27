#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

public_entrypoints=(
  diagnostic.sh
  install.sh
  menu.sh
  repair.sh
  prepare-preapply-backup.sh
  diagnostics/applications-doctor
  diagnostics/backup-doctor
  diagnostics/baseline-doctor
  diagnostics/gnome-doctor
  diagnostics/graphics-doctor
  diagnostics/media-doctor
  diagnostics/storage-doctor
  diagnostics/suspend-doctor
  diagnostics/virtualization-doctor
  diagnostics/workstation-doctor
  diagnostics/wsl2-doctor
  scripts/collect-boot-failure.sh
  scripts/backup/backup-now.sh
  scripts/backup/disaster-recovery.sh
  scripts/backup/restore.sh
  scripts/kvm/configure_nautilus_vm_access.sh
  scripts/kvm/create_ubuntu_devops_vm.sh
  scripts/kvm/create_windows11_vm.sh
  scripts/kvm/runtime_certification.sh
)

for file in "${public_entrypoints[@]}"; do
  [[ -f "$ROOT/$file" ]] || { echo "missing public entrypoint: $file" >&2; exit 1; }
  [[ -x "$ROOT/$file" ]] || { echo "public entrypoint is not executable: $file" >&2; exit 1; }
  bash -n "$ROOT/$file"
done

grep -Fq 'REAL_MACHINE_APPROVED="false"' "$ROOT/config/local.conf.example"
grep -Fq 'runtime_environment_detect' "$ROOT/lib/common.sh"
grep -Fq 'runtime_is_baremetal' "$ROOT/lib/apply_gate.sh"
grep -Fq 'runtime_is_baremetal' "$ROOT/lib/baseline.sh"
grep -Fq 'wsl2)' "$ROOT/diagnostic.sh"
grep -Fq 'EXPECTED' "$ROOT/diagnostics/wsl2-doctor"

echo 'public entrypoints: PASS'

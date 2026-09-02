#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
public_entrypoints=(
  control.sh diagnostic.sh install.sh menu.sh repair.sh prepare-preapply-backup.sh
  diagnostics/applications-doctor diagnostics/backup-doctor diagnostics/baseline-doctor diagnostics/display-doctor diagnostics/final-certification diagnostics/gnome-doctor diagnostics/graphics-doctor diagnostics/kernel-doctor diagnostics/media-doctor diagnostics/nautilus-coldstart-doctor diagnostics/storage-doctor diagnostics/suspend-doctor diagnostics/virtualization-doctor diagnostics/virtualbox-gnome-lab-doctor diagnostics/workstation-doctor diagnostics/wsl2-doctor
  installer/generate-fedora44-kickstart.sh
  scripts/collect-boot-failure.sh scripts/backup/backup-now.sh scripts/backup/daily-user-backup.sh scripts/backup/disaster-recovery.sh scripts/backup/restore.sh
  scripts/maintenance/update-system.sh
  scripts/kernel/rollback-to-fedora.sh scripts/kvm/configure_nautilus_vm_access.sh scripts/kvm/create_ubuntu_devops_vm.sh scripts/kvm/create_windows11_vm.sh scripts/kvm/runtime_certification.sh
  scripts/gnome/display-repair.sh scripts/gnome/display-watch.sh scripts/gnome/nautilus-prewarm.sh scripts/lab/apply-gnome-virtualbox.sh
)
for file in "${public_entrypoints[@]}"; do
  [[ -f "$ROOT/$file" ]] || { echo "missing public entrypoint: $file" >&2; exit 1; }
  [[ -x "$ROOT/$file" ]] || { echo "public entrypoint is not executable: $file" >&2; exit 1; }
  bash -n "$ROOT/$file"
done
grep -Fq 'REAL_MACHINE_APPROVED="false"' "$ROOT/config/local.conf.example"
grep -Fq 'runtime_environment_detect' "$ROOT/lib/common.sh"
grep -Fq 'runtime_is_baremetal' "$ROOT/lib/apply_gate.sh"
grep -Fq 'runtime_is_virtualbox' "$ROOT/lib/common.sh"
grep -Fq 'wsl2)' "$ROOT/diagnostic.sh"
grep -Fq 'control_center_main' "$ROOT/control.sh"
grep -Fq 'exec "$REPO_ROOT/control.sh" "$@"' "$ROOT/menu.sh"
echo 'public entrypoints: PASS'

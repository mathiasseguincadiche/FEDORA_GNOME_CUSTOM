#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for file in config/kernel.conf config/power.conf config/platform-msi-b850m-mortar.conf config/systemd-stability.conf modules/hardware/16_platform_topology.sh modules/hardware/17_kernel_power.sh modules/hardware/18_stability_observability.sh diagnostics/kernel-doctor diagnostics/hardware-topology-doctor diagnostics/display-pipeline-doctor diagnostics/power-doctor diagnostics/crash-doctor diagnostics/last-boot-doctor scripts/hardware/suspend-certify.sh scripts/hardware/stability-stress.sh scripts/hardware/workstation-certify.sh systemd/fedora-gnome-custom-boot-health.service systemd/fedora-gnome-custom-resume-health.service; do [[ -f "$ROOT/$file" ]] || { echo "missing tailored hardware file: $file" >&2; exit 1; }; done
grep -Fq 'KERNEL_AUTOMATIC_CUSTOM_BUILD="false"' "$ROOT/config/kernel.conf"
grep -Fq 'PLATFORM_FIRMWARE_MUTATION_ALLOWED="false"' "$ROOT/config/platform-msi-b850m-mortar.conf"
grep -Fq 'POWER_ALLOW_MEM_SLEEP_OVERRIDE="false"' "$ROOT/config/power.conf"
grep -Fq 'SYSTEMD_ENABLE_KDUMP_AUTOMATIC="false"' "$ROOT/config/systemd-stability.conf"
grep -Fq 'hardware.topology|HARDWARE|hardware.peripherals' "$ROOT/manifests/module-plan.conf"
grep -Fq 'hardware.kernel_power|HARDWARE|hardware.topology' "$ROOT/manifests/module-plan.conf"
grep -Fq 'hardware.observability|HARDWARE|hardware.kernel_power' "$ROOT/manifests/module-plan.conf"
for forbidden in lspci journalctl nvme wayland-info vulkaninfo vainfo; do if grep -Fq "$forbidden" "$ROOT/scripts/systemd/fedora-custom-sleep-hook"; then echo "heavy command in sleep hook: $forbidden" >&2; exit 1; fi; done
grep -Fq 'systemctl --no-block start fedora-gnome-custom-resume-health.service' "$ROOT/scripts/systemd/fedora-custom-sleep-hook"
grep -Fq 'Storage=persistent' "$ROOT/systemd/journald-80-fedora-gnome-custom.conf"
grep -Fq 'stress-ng' "$ROOT/scripts/hardware/stability-stress.sh"
grep -Fq 'POWER_SUSPEND_CERTIFICATION_CYCLES="10"' "$ROOT/config/power.conf"
echo 'hardware tailored stability contract: PASS'

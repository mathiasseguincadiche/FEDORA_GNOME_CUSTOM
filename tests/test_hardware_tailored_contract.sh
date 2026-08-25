#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for file in config/kernel.conf config/power.conf config/platform-msi-b850m-mortar.conf config/systemd-stability.conf modules/hardware/16_platform_topology.sh modules/hardware/17_kernel_power.sh modules/hardware/18_stability_observability.sh diagnostics/kernel-doctor diagnostics/hardware-topology-doctor diagnostics/display-pipeline-doctor diagnostics/power-doctor diagnostics/crash-doctor diagnostics/last-boot-doctor diagnostics/network-doctor diagnostics/audio-doctor scripts/hardware/suspend-certify.sh scripts/hardware/stability-stress.sh scripts/hardware/workstation-certify.sh systemd/fedora-gnome-custom-boot-health.service systemd/fedora-gnome-custom-resume-health.service; do [[ -f "$ROOT/$file" ]] || { echo "missing tailored hardware file: $file" >&2; exit 1; }; done
grep -Fq 'KERNEL_AUTOMATIC_CUSTOM_BUILD="false"' "$ROOT/config/kernel.conf"
grep -Fq 'PLATFORM_FIRMWARE_MUTATION_ALLOWED="false"' "$ROOT/config/platform-msi-b850m-mortar.conf"
grep -Fq 'PLATFORM_REQUIRE_SECURE_BOOT="true"' "$ROOT/config/platform-msi-b850m-mortar.conf"
grep -Fq 'PLATFORM_REQUIRE_REBAR_FOR_ARC="true"' "$ROOT/config/platform-msi-b850m-mortar.conf"
grep -Fq 'POWER_ALLOW_MEM_SLEEP_OVERRIDE="false"' "$ROOT/config/power.conf"
grep -Fq 'SYSTEMD_ENABLE_KDUMP_AUTOMATIC="false"' "$ROOT/config/systemd-stability.conf"
grep -Fxq 'mokutil' "$ROOT/manifests/packages-system.txt"
grep -Fxq 'efibootmgr' "$ROOT/manifests/packages-system.txt"
grep -Fq 'EXPECTED_MEMORY_PROFILE="A-XMP/XMP 3.0"' "$ROOT/config/hardware.conf"
grep -Fq 'configured" != "$expected_speed' "$ROOT/scripts/hardware/stability-stress.sh"
grep -Fq 'EXPECTED_LAN_PCI_DEVICE="8126"' "$ROOT/config/hardware.conf"
grep -Fq 'EXPECTED_LAN_KERNEL_DRIVER="r8169"' "$ROOT/config/hardware.conf"
grep -Fq 'hardware.topology|HARDWARE|hardware.peripherals' "$ROOT/manifests/module-plan.conf"
grep -Fq 'hardware.kernel_power|HARDWARE|hardware.topology' "$ROOT/manifests/module-plan.conf"
grep -Fq 'hardware.observability|HARDWARE|hardware.kernel_power' "$ROOT/manifests/module-plan.conf"
for forbidden in lspci journalctl nvme wayland-info vulkaninfo vainfo; do if grep -Fq "$forbidden" "$ROOT/scripts/systemd/fedora-custom-sleep-hook"; then echo "heavy command in sleep hook: $forbidden" >&2; exit 1; fi; done
grep -Fq 'systemctl --no-block start fedora-gnome-custom-resume-health.service' "$ROOT/scripts/systemd/fedora-custom-sleep-hook"
grep -Fq 'Storage=persistent' "$ROOT/systemd/journald-80-fedora-gnome-custom.conf"
grep -Fq 'stress-ng' "$ROOT/scripts/hardware/stability-stress.sh"
grep -Fq 'POWER_SUSPEND_CERTIFICATION_CYCLES="10"' "$ROOT/config/power.conf"
grep -Fq '37) Certification workstation finale' "$ROOT/menu.sh"
grep -Fq 'hardware-topology-doctor' "$ROOT/diagnostics/workstation-doctor"
grep -Fq 'RTL8126-VB/upstream driver contract' "$ROOT/diagnostics/workstation-doctor"
grep -Fq 'latest-resume.log' "$ROOT/diagnostics/suspend-doctor"
echo 'hardware tailored stability contract: PASS'

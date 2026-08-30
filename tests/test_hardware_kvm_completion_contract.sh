#!/usr/bin/env bash
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(<"$root/VERSION")"
[[ "$(printf '%s\n' '0.8.1' "$version" | sort -V | head -n1)" == '0.8.1' ]]
grep -Fxq amd-ucode-firmware "$root/manifests/packages-system.txt"
grep -Fxq intel-gpu-firmware "$root/manifests/packages-system.txt"
for p in iw bluez alsa-utils; do grep -Fxq "$p" "$root/manifests/packages-hardware.txt"; done
grep -Fq 'amd-ucode-firmware' "$root/modules/system/02_firmware_microcode.sh"
grep -Fq 'intel-gpu-firmware' "$root/modules/system/02_firmware_microcode.sh"
grep -Fq 'r8169' "$root/config/hardware-components.conf"
grep -Fq '5000' "$root/diagnostics/hardware-components-doctor"
grep -Fq 'EHT' "$root/diagnostics/hardware-components-doctor"
grep -Fq 'ALC4080' "$root/diagnostics/hardware-components-doctor"
grep -Fq 'xhci_hcd' "$root/diagnostics/usb-resume-doctor"
grep -Fq 'software-matrix-doctor' "$root/diagnostics/final-certification"
grep -Fq 'usb-resume-doctor' "$root/diagnostics/final-certification"
grep -Fq 'io_uring' "$root/diagnostics/kvm-io-doctor"
grep -Fq 'libaio' "$root/diagnostics/kvm-io-doctor"
for f in scripts/kvm/create_ubuntu_devops_vm.sh scripts/kvm/create_windows11_vm.sh; do
  grep -Fq 'org.qemu.guest_agent.0' "$root/$f"
  grep -Fq -- '--rng /dev/urandom' "$root/$f"
  grep -Fq -- '--memballoon virtio' "$root/$f"
done
grep -Fq 'com.redhat.spice.0' "$root/scripts/kvm/create_windows11_vm.sh"
grep -Fq 'QEMU-GA' "$root/guest/windows-11/configure-guest-integration.ps1"
grep -Fq 'pnputil.exe' "$root/guest/windows-11/configure-guest-integration.ps1"
grep -Fq 'qemu-agent-command' "$root/scripts/kvm/runtime_certification.sh"
grep -Fq 'test_hardware_kvm_completion_contract.sh' "$root/.github/workflows/tests.yml"
echo 'Hardware/KVM completion contract OK'

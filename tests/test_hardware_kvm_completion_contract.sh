#!/usr/bin/env bash
# Hardware/KVM completion specification: the package sets, the forbidden NCT6687
# overrides and the baseline evidence fields. Behaviour is exercised by
# test_hardware_kvm_behavior.sh, test_hardware_platform_behavior.sh,
# test_rocky_vm_creation_behavior.sh and test_rocky_kvm_runtime_behavior.py.
set -Eeuo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "hardware/KVM completion contract: FAIL: $*" >&2; exit 1; }

version="$(<"$root/VERSION")"
[[ "$(printf '%s\n' '0.8.1' "$version" | sort -V | head -n1)" == 0.8.1 ]] || fail "VERSION below 0.8.1: $version"
for p in amd-ucode-firmware intel-gpu-firmware; do grep -Fxq "$p" "$root/manifests/packages-system.txt" || fail "system package missing: $p"; done
for p in iw bluez alsa-utils lm_sensors; do grep -Fxq "$p" "$root/manifests/packages-hardware.txt" || fail "hardware package missing: $p"; done
grep -Fxq 'HARDWARE_LAN_DRIVER="r8169"' "$root/config/hardware-components.conf" || fail 'LAN driver changed'
grep -Fxq 'HARDWARE_NCT6683_FORCE="false"' "$root/config/hardware-components.conf" || fail 'nct6683 force must default to false'

# Only the in-tree nct6683 at boot; force=1 lives solely in the opt-in modprobe file.
if grep -Eq 'force[[:space:]]*=[[:space:]]*1|force=1|msi_fan_brute_force' "$root/systemd/modules-load.d/fedora-gnome-custom-hwmon.conf" "$root/lib/hardware_platform.sh"; then
  fail 'unsafe NCT6687 force option or third-party-style override detected'
fi
grep -Fxq 'options nct6683 force=1' "$root/systemd/modprobe.d/fedora-gnome-custom-nct6683-force.conf" || fail 'opt-in force file changed'

# The pre-APPLY baseline records every platform proof.
for field in wifi_identity_lock nct6687_hwmon dmi_platform amd_pstate cpu_boost; do
  grep -Fq "$field=PASS" "$root/lib/baseline.sh" || fail "baseline does not record $field"
done
for doctor in software-matrix-doctor usb-resume-doctor; do
  grep -Fq "diagnostics/$doctor" "$root/diagnostics/final-certification" || fail "final certification skips $doctor"
done
grep -Fq 'runtime_certification_core.sh' "$root/scripts/kvm/runtime_certification.sh" || fail 'KVM runtime certification bypasses its strict core'
echo 'Hardware/KVM completion contract OK'

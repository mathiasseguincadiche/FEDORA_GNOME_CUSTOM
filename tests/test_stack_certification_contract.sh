#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for f in lib/driver_contract.sh lib/kvm_contract.sh lib/application_runtime.sh diagnostics/driver-doctor diagnostics/kvm-domain-doctor diagnostics/application-runtime-doctor manifests/application-runtime-contract.tsv; do
  [[ -s "$ROOT/$f" ]] || { echo "missing stack certification file: $f" >&2; exit 1; }
done
for lib in driver_contract.sh kvm_contract.sh application_runtime.sh; do
  grep -Fq "lib/$lib" "$ROOT/lib/bootstrap.sh" || { echo "bootstrap missing $lib" >&2; exit 1; }
done

grep -Fq 'diagnostics/driver-doctor' "$ROOT/modules/hardware/19_hardware_validation.sh"
grep -Fq 'diagnostics/driver-doctor' "$ROOT/diagnostics/final-certification"
grep -Fq 'diagnostics/application-runtime-doctor' "$ROOT/diagnostics/final-certification"
grep -Fq 'diagnostics/kvm-domain-doctor' "$ROOT/diagnostics/final-certification"
grep -Fq 'driver_contract=PASS' "$ROOT/diagnostics/final-certification"
grep -Fq 'application_runtime_contract=PASS' "$ROOT/diagnostics/final-certification"
grep -Fq 'kvm_domain_contract=PASS' "$ROOT/diagnostics/final-certification"

grep -Fq "find \"\$REPO_ROOT/manifests\"" "$ROOT/lib/evidence.sh"
grep -Fq "find \"\$REPO_ROOT/virtualization/xml\"" "$ROOT/lib/evidence.sh"
grep -Fq "fedora44-media.lock" "$ROOT/lib/evidence.sh"

for module in xe r8169 nvme xhci_hcd snd_usb_audio nct6683; do grep -Fq "$module" "$ROOT/lib/driver_contract.sh" || { echo "driver contract missing $module" >&2; exit 1; }; done
grep -Fq 'modinfo -F intree' "$ROOT/lib/driver_contract.sh"
grep -Fq 'akmod-nvidia' "$ROOT/lib/driver_contract.sh"
grep -Fq 'host-passthrough' "$ROOT/lib/kvm_contract.sh"
grep -Fq 'enrolled-keys' "$ROOT/lib/kvm_contract.sh"
grep -Fq 'host device passthrough is forbidden' "$ROOT/lib/kvm_contract.sh"
grep -Fq 'flatpak info --show-origin' "$ROOT/lib/application_runtime.sh"
grep -Fq 'flatpak run --command=/usr/bin/true' "$ROOT/lib/application_runtime.sh"
grep -Fq 'desktop-file-validate' "$ROOT/lib/application_runtime.sh"

grep -Fq "trusted SHA-256 is mandatory for both Windows and VirtIO media" "$ROOT/scripts/kvm/create_windows11_vm.sh"
forbidden_io_source="source \"\$io_state\""
if grep -Fq "$forbidden_io_source" "$ROOT/scripts/kvm/create_windows11_vm.sh" "$ROOT/scripts/kvm/create_ubuntu_devops_vm.sh"; then
  echo 'KVM I/O state must not be sourced as shell' >&2
  exit 1
fi

for test in test_driver_runtime_behavior.sh test_kvm_xml_policy_behavior.sh test_application_runtime_behavior.sh test_stack_certification_contract.sh; do
  grep -Fq "$test" "$ROOT/.github/workflows/tests.yml" || { echo "CI missing $test" >&2; exit 1; }
done

echo 'stack certification contract: PASS'

#!/usr/bin/env bash
# Stack certification wiring: the runtime contracts are loaded by the engine,
# executed by validation and recorded in the final certificate. Behaviour is
# exercised by test_stack_certification_behavior.sh (driver contract, effective
# configuration hash), test_driver_runtime_behavior.sh,
# test_kvm_xml_policy_behavior.sh and test_application_runtime_behavior.sh.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "stack certification contract: FAIL: $*" >&2; exit 1; }

for lib in driver_contract.sh kvm_contract.sh application_runtime.sh; do
  grep -Fq "lib/$lib" "$ROOT/lib/bootstrap.sh" || fail "bootstrap missing $lib"
done
grep -Fq 'diagnostics/driver-doctor' "$ROOT/modules/hardware/19_hardware_validation.sh" || fail 'hardware validation skips the driver doctor'
for doctor in driver-doctor application-runtime-doctor kvm-domain-doctor; do
  grep -Fq "diagnostics/$doctor" "$ROOT/diagnostics/final-certification" || fail "final certification skips $doctor"
done
for field in driver_contract application_runtime_contract kvm_domain_contract; do
  grep -Fq "$field=PASS" "$ROOT/diagnostics/final-certification" || fail "certificate does not record $field"
done

forbidden_io_source="source \"\$io_state\""
if grep -Fq "$forbidden_io_source" "$ROOT/scripts/kvm/create_rocky_devops_vm.sh"; then
  fail 'KVM I/O state must not be sourced as shell'
fi

echo 'stack certification contract: PASS'

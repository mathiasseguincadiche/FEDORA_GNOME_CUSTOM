#!/usr/bin/env bash
set -Eeuo pipefail

kvm_preflight_arc_owned_by_host() {
  local dev vendor device driver
  for dev in /sys/bus/pci/devices/*; do
    [[ -r "$dev/vendor" && -r "$dev/device" ]] || continue
    vendor="$(normalize_hex "$(<"$dev/vendor")")"
    device="$(normalize_hex "$(<"$dev/device")")"
    [[ "$vendor" == "8086" && "$device" == "e20b" ]] || continue
    [[ -L "$dev/driver" ]] || return 1
    driver="$(basename "$(readlink -f "$dev/driver")")"
    [[ "$driver" == "xe" ]]
    return
  done
  return 1
}

kvm_preflight_network_overlap() {
  local cidr="${KVM_NETWORK_CIDR:-192.168.50.0/24}"
  command_exists python3 || return 1
  python3 - "$cidr" <<'PY'
import ipaddress
import subprocess
import sys

wanted = ipaddress.ip_network(sys.argv[1], strict=False)
out = subprocess.run(['ip', '-4', 'route', 'show', 'scope', 'link'], text=True, capture_output=True, check=True).stdout
for line in out.splitlines():
    fields = line.split()
    if not fields or '/' not in fields[0]:
        continue
    try:
        current = ipaddress.ip_network(fields[0], strict=False)
    except ValueError:
        continue
    if current == wanted:
        continue
    if wanted.overlaps(current):
        print(f'configured KVM subnet {wanted} overlaps host-connected route {current}', file=sys.stderr)
        raise SystemExit(1)
PY
}

kvm_preflight_precheck() {
  is_true "${ENABLE_KVM:-true}" || return 0
  command_exists lscpu && command_exists ip || return "$EXIT_PRECHECK_FAILED"
  grep -Eq 'svm|AMD-V' <(lscpu) || { log_error KVM 'AMD-V/SVM not detected'; return "$EXIT_PRECHECK_FAILED"; }
  [[ -c /dev/kvm ]] || { log_error KVM '/dev/kvm missing; verify SVM in UEFI'; return "$EXIT_PRECHECK_FAILED"; }
  [[ -d /sys/module/kvm_amd ]] || { log_error KVM 'kvm_amd is not loaded'; return "$EXIT_PRECHECK_FAILED"; }
  is_true "${ALLOW_GPU_PASSTHROUGH:-false}" && { log_error KVM 'GPU passthrough is forbidden by workstation policy'; return "$EXIT_PRECHECK_FAILED"; }
  kvm_preflight_arc_owned_by_host || { log_error KVM 'Intel Arc B580 must remain bound to xe on the HOST'; return "$EXIT_PRECHECK_FAILED"; }
  kvm_preflight_network_overlap || { log_error KVM 'devops-nat overlaps an existing host network'; return "$EXIT_PRECHECK_FAILED"; }
  if is_true "${KVM_FIREWALLD_REQUIRED:-true}"; then
    command_exists firewall-cmd || return "$EXIT_PRECHECK_FAILED"
    firewall-cmd --state >/dev/null 2>&1 || { log_error KVM 'firewalld must be active'; return "$EXIT_PRECHECK_FAILED"; }
  fi
}

kvm_preflight_plan() {
  cat <<'EOF'
READ-ONLY KVM PREFLIGHT:
- validate AMD-V/SVM, /dev/kvm and kvm_amd
- verify the Intel Arc B580 is still owned by the HOST xe driver
- reject overlap between devops-nat and existing host-connected IPv4 networks
- require active firewalld before libvirt networking
- never enable VFIO/GPU passthrough
EOF
}

kvm_preflight_apply() { :; }
kvm_preflight_postcheck() { :; }

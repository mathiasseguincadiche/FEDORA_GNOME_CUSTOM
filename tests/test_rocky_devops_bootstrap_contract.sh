#!/usr/bin/env bash
# Rocky DevOps guest specification. The bootstrap and its tools run for real in
# the Rocky 10.2 lab (.github/workflows/vm-pretest.yml, verify-devops.sh) and
# the VM creation in test_rocky_vm_creation_behavior.sh; this file keeps the
# supply-chain and security rules a successful install would not reveal.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOOT="$ROOT/guest/rocky-devops/bootstrap-devops.sh"
fail() { echo "rocky devops bootstrap contract: FAIL: $*" >&2; exit 1; }

# Downloads are pinned and verified, never "latest" or piped to a shell.
if grep -Eq 'releases/latest|/latest/download' "$BOOT"; then fail 'unpinned latest download'; fi
if grep -RInE '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh)' "$ROOT/guest/rocky-devops" "$ROOT/scripts/kvm" >/dev/null; then
  fail 'curl/wget piped to a shell'
fi
if grep -Eq 'gpgcheck=0' "$BOOT"; then fail 'repository signature checking disabled'; fi

# Rocky provisioning stays Rocky-native, SELinux enforcing, no host directory sharing,
# no clear-text guest password.
if grep -Eq 'apt-get|dpkg|/etc/apt/|setenforce[[:space:]]+0' "$BOOT"; then fail 'Debian tooling or weakened SELinux'; fi
if grep -RInEi 'virtiofs|hostshare|/data/libvirt/shared' "$ROOT/guest/rocky-devops" "$ROOT/scripts/kvm/create_rocky_devops_vm.sh" >/dev/null; then
  fail 'host directory sharing in Rocky provisioning'
fi
if grep -RInE 'guest_password=.*guest|password:[[:space:]]*guest|passwd:[[:space:]]*guest' "$ROOT/guest/rocky-devops" "$ROOT/scripts/kvm" >/dev/null; then
  fail 'clear-text guest password'
fi

python3 -B "$ROOT/tests/test_rocky_bootstrap_marker.py"
# Regression: Rocky's mirrors can publish a new kernel between the two guest
# boots. The second provisioning pass must validate the *first* kernel target,
# not install a newer default kernel and misreport the successful boot as FAIL.
python3 - "$BOOT" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
checks = (
    "prepared_kernel=''",
    'if [[ -e "$reboot_pending" || -L "$reboot_pending" ]]; then',
    '"$(uname -r)" == "$prepared_kernel"',
    '[[ -f "/boot/vmlinuz-$prepared_kernel" ]]',
    'kernel_dnf_options=(--exclude=\'kernel*\')',
    'dnf -y upgrade --refresh "${kernel_dnf_options[@]}"',
    'dnf -y install "${kernel_dnf_options[@]}" grubby kmod',
    '[[ -n "$prepared_kernel" && "$default_kernel" != "$prepared_kernel" ]]',
    'rm -f -- "$reboot_pending"',
)
for check in checks:
    assert check in source, f"Rocky kernel transaction invariant missing: {check}"
assert source.index("prepared_kernel=''") < source.index("dnf -y upgrade --refresh")
assert source.index('rm -f -- "$reboot_pending"') > source.index(
    'mv -f /var/lib/fedora-gnome-custom/rocky-devops-bootstrap.env.tmp')
assert 'SuccessExitStatus=75' in Path(
    sys.argv[1]).with_name("devops-bootstrap.service").read_text()
PY
echo 'rocky devops ready-to-work bootstrap contract: PASS'

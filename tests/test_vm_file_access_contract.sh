#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HELPER="$ROOT/scripts/kvm/configure_nautilus_vm_access.sh"
ROCKY_CREATE="$ROOT/scripts/kvm/create_rocky_devops_vm.sh"

for token in 'VM_NAUTILUS_ACCESS_ENABLED="true"' 'ROCKY_SERVER_NAUTILUS_LABEL="Rocky DevOps"'; do
  grep -Fq "$token" "$ROOT/config/vm-profiles.conf" || { echo "missing VM file-access config: $token" >&2; exit 1; }
done

grep -Fq 'kvm.file_access|KVM|kvm.ssh|modules/virtualization/36b_kvm_file_access.sh' "$ROOT/manifests/module-plan.conf"
grep -Fq 'kvm.virt_manager|KVM|kvm.file_access|' "$ROOT/manifests/module-plan.conf"
for token in 'gtk-3.0/bookmarks' 'sftp://' 'net-dhcp-leases' 'gio open' 'Rocky DevOps'; do
  grep -Fq "$token" "$HELPER" || { echo "missing Nautilus helper contract: $token" >&2; exit 1; }
done
grep -Fq 'configure_nautilus_vm_access.sh' "$ROCKY_CREATE"
echo 'VM Nautilus/SFTP file-access contract: PASS'

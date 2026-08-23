#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HELPER="$ROOT/scripts/kvm/configure_nautilus_vm_access.sh"
WIN="$ROOT/guest/windows-11/configure-smb-share.ps1"
WIN_CREATE="$ROOT/scripts/kvm/create_windows11_vm.sh"
UBUNTU_CREATE="$ROOT/scripts/kvm/create_ubuntu_devops_vm.sh"

for token in \
  'VM_NAUTILUS_ACCESS_ENABLED="true"' \
  'UBUNTU_SERVER_NAUTILUS_LABEL="Ubuntu DevOps"' \
  'WINDOWS11_SMB_SHARE_NAME="VM-Share"' \
  'WINDOWS11_NAUTILUS_LABEL="Windows VM"'; do
  grep -Fq "$token" "$ROOT/config/vm-profiles.conf" || { echo "missing VM file-access config: $token" >&2; exit 1; }
done

grep -Fxq 'xorriso' "$ROOT/manifests/packages-virtualization.txt"
grep -Fq 'kvm.file_access|KVM|kvm.ssh|modules/virtualization/36b_kvm_file_access.sh' "$ROOT/manifests/module-plan.conf"
grep -Fq 'kvm.virt_manager|KVM|kvm.file_access|' "$ROOT/manifests/module-plan.conf"

for token in 'gtk-3.0/bookmarks' 'sftp://' 'smb://' 'net-dhcp-leases' 'gio open' 'Ubuntu DevOps' 'Windows VM'; do
  grep -Fq "$token" "$HELPER" || { echo "missing Nautilus helper contract: $token" >&2; exit 1; }
done

for token in 'New-SmbShare' 'Grant-SmbShareAccess' 'New-NetFirewallRule' '-LocalPort 445' "192.168.50.0/24" "C:\\VM-Share"; do
  grep -Fq -- "$token" "$WIN" || { echo "missing Windows SMB contract: $token" >&2; exit 1; }
done

if grep -Eq -- '-(FullAccess|ChangeAccess|ReadAccess)[^\n]*(Everyone|Guest)' "$WIN"; then
  echo 'broad unauthenticated Windows SMB access is forbidden' >&2
  exit 1
fi

for token in 'xorriso -as mkisofs' 'FGC_TOOLS' 'Configure-VMShare.ps1' 'WINDOWS11_SMB_SETUP_SCRIPT' 'configure_nautilus_vm_access.sh'; do
  grep -Fq "$token" "$WIN_CREATE" || { echo "missing Windows guest-tools integration: $token" >&2; exit 1; }
done
grep -Fq 'configure_nautilus_vm_access.sh' "$UBUNTU_CREATE"

echo 'VM Nautilus/SFTP/SMB file-access contract: PASS'

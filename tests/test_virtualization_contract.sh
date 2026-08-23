#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for pkg in qemu-kvm qemu-img libvirt libvirt-client libvirt-client-qemu libvirt-nss libvirt-daemon-common libvirt-daemon-kvm libvirt-daemon-config-network virt-install virt-manager virt-viewer virt-top virt-v2v cloud-utils-cloud-localds edk2-ovmf swtpm swtpm-tools swtpm-selinux virtiofsd guestfs-tools guestfs-tools-bash-completion osinfo-db osinfo-db-tools libosinfo openssh-clients iputils rsync nftables dnsmasq python3 policycoreutils-python-utils; do
  grep -Fxq "$pkg" "$ROOT/manifests/packages-virtualization.txt" || { echo "missing virtualization package: $pkg" >&2; exit 1; }
done

for entry in \
  'kvm.preflight|KVM|applications.validation|modules/virtualization/30_kvm_preflight.sh' \
  'kvm.stack|KVM|kvm.preflight|modules/virtualization/31_kvm_stack.sh' \
  'kvm.firmware|KVM|kvm.stack|modules/virtualization/32_kvm_firmware_uefi_tpm.sh' \
  'kvm.storage|KVM|kvm.firmware|modules/virtualization/33_kvm_storage_pools.sh' \
  'kvm.network|KVM|kvm.storage|modules/virtualization/34_kvm_network.sh' \
  'kvm.catalog|KVM|kvm.network|modules/virtualization/35_kvm_os_catalog.sh' \
  'kvm.cli|KVM|kvm.catalog|modules/virtualization/36_kvm_cli_management.sh' \
  'kvm.ssh|KVM|kvm.cli|modules/virtualization/36a_kvm_ssh_access.sh' \
  'kvm.virt_manager|KVM|kvm.ssh|modules/virtualization/37_kvm_virt_manager.sh' \
  'kvm.vm_profiles|KVM|kvm.virt_manager|modules/virtualization/38_kvm_vm_profiles.sh' \
  'kvm.validation|KVM|kvm.vm_profiles|modules/virtualization/39_kvm_validation.sh'; do
  grep -Fxq "$entry" "$ROOT/manifests/module-plan.conf" || { echo "missing KVM module contract: $entry" >&2; exit 1; }
done

grep -Fq 'backup.preflight|BACKUP|kvm.validation|' "$ROOT/manifests/module-plan.conf"
grep -Fq 'KVM_REQUIRE_DEDICATED_STORAGE="true"' "$ROOT/config/virtualization.conf"
grep -Fq 'KVM_DATA_MOUNT="/data"' "$ROOT/config/virtualization.conf"
grep -Fq 'KVM_DATA_FSTYPE="ext4"' "$ROOT/config/virtualization.conf"
grep -Fq 'KVM_BLOCK_PHYSICAL_LAN="true"' "$ROOT/config/virtualization.conf"
grep -Fq 'KVM_FIREWALLD_ZONE="libvirt"' "$ROOT/config/virtualization.conf"
grep -Fq 'ALLOW_GPU_PASSTHROUGH="false"' "$ROOT/config/virtualization.conf"
grep -Fq 'CREATE_DEVOPS_VM="false"' "$ROOT/config/virtualization.conf"

grep -Fq "zone='libvirt'" "$ROOT/virtualization/xml/networks/devops-nat.xml"
grep -Fq "<forwarder addr='9.9.9.9'" "$ROOT/virtualization/xml/networks/devops-nat.xml"
grep -Fq "<forwarder addr='1.1.1.1'" "$ROOT/virtualization/xml/networks/devops-nat.xml"
grep -Fq 'fedora_gnome_custom_kvm' "$ROOT/scripts/kvm/kvm_network_guard.sh"
grep -Fq '/sys/class/net/' "$ROOT/scripts/kvm/kvm_network_guard.sh"
grep -Fq '/device' "$ROOT/scripts/kvm/kvm_network_guard.sh"
grep -Fq 'semanage fcontext' "$ROOT/modules/virtualization/33_kvm_storage_pools.sh"
grep -Fq 'restorecon -R' "$ROOT/modules/virtualization/33_kvm_storage_pools.sh"

for cli in virt-admin virt-host-validate virt-xml-validate virt-xml qemu-io qemu-nbd qemu-storage-daemon virt-customize virt-sysprep virt-resize virt-sparsify virt-builder cloud-localds virt-top virt-v2v virt-qemu-qmp-proxy rsync; do
  grep -Fq "$cli" "$ROOT/modules/virtualization/36_kvm_cli_management.sh" || { echo "missing CLI validation: $cli" >&2; exit 1; }
done

grep -Fq 'UBUNTU_SERVER_RELEASE="26.04"' "$ROOT/config/vm-profiles.conf"
grep -Fq 'FEDORA_VM_RELEASE="44"' "$ROOT/config/vm-profiles.conf"
grep -Fq 'WINDOWS11_FIRMWARE="uefi-secureboot"' "$ROOT/config/vm-profiles.conf"
grep -Fq 'WINDOWS11_TPM_VERSION="2.0"' "$ROOT/config/vm-profiles.conf"
grep -Fq 'VM_PROFILE_GPU_PASSTHROUGH_ALLOWED="false"' "$ROOT/config/vm-profiles.conf"

[[ -f "$ROOT/diagnostics/virtualization-doctor" ]]
[[ -f "$ROOT/modules/virtualization/36a_kvm_ssh_access.sh" ]]
[[ ! -e "$ROOT/modules/virtualization/32_kvm_network.sh" ]]

! grep -RInE --exclude-dir=.git '(mkfs\.|wipefs|parted |sgdisk |chmod[[:space:]]+777|setenforce[[:space:]]+0)' "$ROOT/modules/virtualization" "$ROOT/scripts/kvm" || {
  echo 'forbidden destructive/insecure virtualization mutation found' >&2
  exit 1
}

echo 'virtualization contract: PASS'

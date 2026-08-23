#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

for pkg in qemu-kvm qemu-img libvirt libvirt-client libvirt-client-qemu libvirt-nss libvirt-daemon-common libvirt-daemon-kvm libvirt-daemon-config-network virt-install virt-manager virt-viewer virt-top virt-v2v cloud-utils-cloud-localds openssl edk2-ovmf swtpm swtpm-tools swtpm-selinux guestfs-tools guestfs-tools-bash-completion osinfo-db osinfo-db-tools libosinfo openssh-clients iputils rsync nftables dnsmasq python3 policycoreutils-python-utils; do
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
grep -Fq "<ip address='192.168.50.254' netmask='255.255.255.0'>" "$ROOT/virtualization/xml/networks/devops-nat.xml"
grep -Fq "<range start='192.168.50.100' end='192.168.50.200'/>" "$ROOT/virtualization/xml/networks/devops-nat.xml"
grep -Fq "forwarder addr='9.9.9.9'" "$ROOT/virtualization/xml/networks/devops-nat.xml"
grep -Fq "forwarder addr='1.1.1.1'" "$ROOT/virtualization/xml/networks/devops-nat.xml"
grep -Fq 'fedora_gnome_custom_kvm' "$ROOT/scripts/kvm/kvm_network_guard.sh"
grep -Fq 'semanage fcontext' "$ROOT/modules/virtualization/33_kvm_storage_pools.sh"
grep -Fq 'restorecon -R' "$ROOT/modules/virtualization/33_kvm_storage_pools.sh"

for cli in virt-admin virt-host-validate virt-xml-validate virt-xml qemu-io qemu-nbd qemu-storage-daemon virt-customize virt-sysprep virt-resize virt-sparsify virt-builder cloud-localds virt-top virt-v2v virt-qemu-qmp-proxy rsync; do
  grep -Fq "$cli" "$ROOT/modules/virtualization/36_kvm_cli_management.sh" || { echo "missing CLI validation: $cli" >&2; exit 1; }
done

for expected in \
  'UBUNTU_SERVER_RELEASE="26.04"' \
  'UBUNTU_SERVER_VCPU="6"' \
  'UBUNTU_SERVER_RAM_MB="16384"' \
  'UBUNTU_SERVER_DISK_GB="160"' \
  'UBUNTU_SERVER_USERNAME="mathias"' \
  'WINDOWS11_VCPU="4"' \
  'WINDOWS11_RAM_MB="12288"' \
  'WINDOWS11_DISK_GB="128"' \
  'WINDOWS11_FIRMWARE="uefi-secureboot"' \
  'WINDOWS11_TPM_VERSION="2.0"' \
  'VM_PROFILE_GPU_PASSTHROUGH_ALLOWED="false"'; do
  grep -Fq "$expected" "$ROOT/config/vm-profiles.conf" || { echo "missing final VM profile value: $expected" >&2; exit 1; }
done

if grep -Fq 'FEDORA_VM_' "$ROOT/config/vm-profiles.conf"; then
  echo 'obsolete Fedora guest profile found' >&2
  exit 1
fi
if grep -Fq 'Fedora 44 lab' "$ROOT/modules/virtualization/38_kvm_vm_profiles.sh"; then
  echo 'obsolete Fedora lab profile text found' >&2
  exit 1
fi

for file in \
  guest/ubuntu-devops/bootstrap-devops.sh \
  guest/ubuntu-devops/verify-devops.sh \
  scripts/kvm/create_ubuntu_devops_vm.sh \
  scripts/kvm/create_windows11_vm.sh \
  scripts/kvm/runtime_certification.sh \
  diagnostics/virtualization-doctor; do
  [[ -f "$ROOT/$file" ]] || { echo "missing runtime/provisioning file: $file" >&2; exit 1; }
done

grep -Fq 'runtime-prompt' "$ROOT/config/vm-profiles.conf"
if grep -RInE --exclude-dir=.git --exclude='test_virtualization_contract.sh' '(password:[[:space:]]*guest|passwd:[[:space:]]*guest|UBUNTU_DEVOPS_PASSWORD=.guest.)' "$ROOT" >/dev/null; then
  echo 'forbidden clear-text guest password pattern found' >&2
  exit 1
fi

if grep -RInEi --exclude-dir=.git --exclude='CHANGELOG.md' --exclude='test_virtualization_contract.sh' 'virtiofs|virtiofsd|hostshare|/mnt/hostshare|/data/libvirt/shared' \
  "$ROOT/config" "$ROOT/manifests" "$ROOT/modules/virtualization" "$ROOT/scripts/kvm" "$ROOT/guest/ubuntu-devops" "$ROOT/diagnostics"; then
  echo 'obsolete host-directory sharing / VirtioFS contract found' >&2
  exit 1
fi

! grep -RInE --exclude-dir=.git '(mkfs\.|wipefs|parted |sgdisk |chmod[[:space:]]+777|setenforce[[:space:]]+0)' "$ROOT/modules/virtualization" "$ROOT/scripts/kvm" || {
  echo 'forbidden destructive/insecure virtualization mutation found' >&2
  exit 1
}

echo 'virtualization contract: PASS'

#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/kvm_contract.sh
source "$ROOT/lib/kvm_contract.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/domcaps.xml" <<'XML'
<domainCapabilities>
  <path>/usr/bin/qemu-system-x86_64</path><domain>kvm</domain><machine>pc-q35-10.0</machine><arch>x86_64</arch>
  <os supported='yes'><enum name='firmware'><value>bios</value><value>efi</value></enum></os>
  <cpu><mode name='host-passthrough' supported='yes'/></cpu>
  <devices><tpm supported='yes'><enum name='model'><value>tpm-crb</value></enum><enum name='backendModel'><value>emulator</value></enum></tpm></devices>
</domainCapabilities>
XML
kvm_contract_validate_domcaps_file "$tmp/domcaps.xml"
sed 's/host-passthrough/host-model/' "$tmp/domcaps.xml" > "$tmp/bad-domcaps.xml"
if kvm_contract_validate_domcaps_file "$tmp/bad-domcaps.xml" >/dev/null 2>&1; then echo 'domcaps without host-passthrough was accepted' >&2; exit 1; fi

export KVM_NETWORK_NAME=devops-nat KVM_POOL_PATH=/data/libvirt/images VM_DISK_IO_DEFAULT=io_uring
export UBUNTU_SERVER_NAME=ubuntu-devops UBUNTU_SERVER_VCPU=6 UBUNTU_SERVER_RAM_MB=16384
export WINDOWS11_NAME=windows-11 WINDOWS11_VCPU=4 WINDOWS11_RAM_MB=12288
cat > "$tmp/ubuntu.xml" <<'XML'
<domain type='kvm'>
  <name>ubuntu-devops</name><memory unit='MiB'>16384</memory><vcpu>6</vcpu>
  <os firmware='efi'><type arch='x86_64' machine='pc-q35-10.0'>hvm</type></os>
  <cpu mode='host-passthrough'/>
  <devices>
    <disk type='file' device='disk'><driver name='qemu' type='qcow2' cache='none' io='io_uring' discard='unmap'/><source file='/data/libvirt/images/ubuntu-devops.qcow2'/><target dev='vda' bus='virtio'/></disk>
    <interface type='network'><source network='devops-nat'/><model type='virtio'/></interface>
    <channel type='unix'><target type='virtio' name='org.qemu.guest_agent.0'/></channel>
    <rng model='virtio'/><memballoon model='virtio'/>
  </devices>
</domain>
XML
kvm_contract_validate_guest_file ubuntu "$tmp/ubuntu.xml" io_uring
sed "s/source network='devops-nat'/source network='default'/" "$tmp/ubuntu.xml" > "$tmp/bad-ubuntu.xml"
if kvm_contract_validate_guest_file ubuntu "$tmp/bad-ubuntu.xml" io_uring >/dev/null 2>&1; then echo 'wrong VM network was accepted' >&2; exit 1; fi
sed "s#</devices>#<hostdev mode='subsystem' type='pci'/></devices>#" "$tmp/ubuntu.xml" > "$tmp/hostdev-ubuntu.xml"
if kvm_contract_validate_guest_file ubuntu "$tmp/hostdev-ubuntu.xml" io_uring >/dev/null 2>&1; then echo 'hostdev passthrough was accepted' >&2; exit 1; fi

cat > "$tmp/windows.xml" <<'XML'
<domain type='kvm'>
  <name>windows-11</name><memory unit='MiB'>12288</memory><vcpu>4</vcpu>
  <os firmware='efi'><type arch='x86_64' machine='pc-q35-10.0'>hvm</type><firmware><feature enabled='yes' name='secure-boot'/><feature enabled='yes' name='enrolled-keys'/></firmware><loader secure='yes'/></os>
  <cpu mode='host-passthrough'/>
  <devices>
    <disk type='file' device='disk'><driver name='qemu' type='qcow2' cache='none' io='io_uring' discard='unmap'/><source file='/data/libvirt/images/windows-11.qcow2'/><target dev='vda' bus='virtio'/></disk>
    <interface type='network'><source network='devops-nat'/><model type='virtio'/></interface>
    <channel type='unix'><target type='virtio' name='org.qemu.guest_agent.0'/></channel>
    <channel type='spicevmc'><target type='virtio' name='com.redhat.spice.0'/></channel>
    <rng model='virtio'/><memballoon model='virtio'/>
    <tpm model='tpm-crb'><backend type='emulator' version='2.0'/></tpm>
    <graphics type='spice'/>
  </devices>
</domain>
XML
kvm_contract_validate_guest_file windows "$tmp/windows.xml" io_uring
sed "s/enabled='yes' name='enrolled-keys'/enabled='no' name='enrolled-keys'/" "$tmp/windows.xml" > "$tmp/bad-windows.xml"
if kvm_contract_validate_guest_file windows "$tmp/bad-windows.xml" io_uring >/dev/null 2>&1; then echo 'Windows without enrolled Secure Boot keys was accepted' >&2; exit 1; fi

echo 'KVM XML policy behavior: PASS'

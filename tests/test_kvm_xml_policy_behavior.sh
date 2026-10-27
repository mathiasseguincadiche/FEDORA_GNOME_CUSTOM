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
  <devices/>
</domainCapabilities>
XML
kvm_contract_validate_domcaps_file "$tmp/domcaps.xml"
sed 's/host-passthrough/host-model/' "$tmp/domcaps.xml" > "$tmp/bad-domcaps.xml"
if kvm_contract_validate_domcaps_file "$tmp/bad-domcaps.xml" >/dev/null 2>&1; then echo 'domcaps without host-passthrough was accepted' >&2; exit 1; fi

export KVM_NETWORK_NAME=devops-nat KVM_POOL_PATH=/data/libvirt/images VM_DISK_IO_DEFAULT=io_uring
export ROCKY_SERVER_NAME=rocky-devops ROCKY_SERVER_VCPU=6 ROCKY_SERVER_RAM_MB=16384
cat > "$tmp/rocky.xml" <<'XML'
<domain type='kvm'>
  <name>rocky-devops</name><memory unit='MiB'>16384</memory><vcpu>6</vcpu>
  <os firmware='efi'><type arch='x86_64' machine='pc-q35-10.0'>hvm</type></os>
  <cpu mode='host-passthrough'/>
  <devices>
    <disk type='file' device='disk'><driver name='qemu' type='qcow2' cache='none' io='io_uring' discard='unmap'/><source file='/data/libvirt/images/rocky-devops.qcow2'/><target dev='vda' bus='virtio'/></disk>
    <interface type='network'><source network='devops-nat'/><model type='virtio'/></interface>
    <channel type='unix'><target type='virtio' name='org.qemu.guest_agent.0'/></channel>
    <rng model='virtio'/><memballoon model='virtio'/>
  </devices>
</domain>
XML
kvm_contract_validate_guest_file rocky "$tmp/rocky.xml" io_uring
sed "s/source network='devops-nat'/source network='default'/" "$tmp/rocky.xml" > "$tmp/bad-rocky.xml"
if kvm_contract_validate_guest_file rocky "$tmp/bad-rocky.xml" io_uring >/dev/null 2>&1; then echo 'wrong VM network was accepted' >&2; exit 1; fi
sed "s#</devices>#<hostdev mode='subsystem' type='pci'/></devices>#" "$tmp/rocky.xml" > "$tmp/hostdev-rocky.xml"
if kvm_contract_validate_guest_file rocky "$tmp/hostdev-rocky.xml" io_uring >/dev/null 2>&1; then echo 'hostdev passthrough was accepted' >&2; exit 1; fi

echo 'KVM XML policy behavior: PASS'

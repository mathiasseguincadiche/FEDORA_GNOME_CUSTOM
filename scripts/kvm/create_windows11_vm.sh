#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=config/virtualization.conf
source "$REPO_ROOT/config/virtualization.conf"
# shellcheck source=config/vm-profiles.conf
source "$REPO_ROOT/config/vm-profiles.conf"

usage() {
  cat <<'EOF'
Usage:
  create_windows11_vm.sh --windows-iso /path/to/windows11.iso --virtio-iso /path/to/virtio-win.iso

Both ISO files are operator-supplied. The project never downloads Windows or VirtIO driver media silently.
EOF
}

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"; }

windows_iso=""
virtio_iso=""
while (($#)); do
  case "$1" in
    --windows-iso) windows_iso="${2:-}"; shift 2 ;;
    --virtio-iso) virtio_iso="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -r "$windows_iso" ]] || { usage; fail 'valid --windows-iso is required'; }
[[ -r "$virtio_iso" ]] || { usage; fail 'valid --virtio-iso is required'; }
for cmd in virsh virt-install qemu-img findmnt; do need "$cmd"; done

uri="${LIBVIRT_URI:-qemu:///system}"
pool="${KVM_POOL_NAME:-devops-data}"
network="${KVM_NETWORK_NAME:-devops-nat}"
name="${WINDOWS11_NAME:-windows-11}"
data_mount="${KVM_DATA_MOUNT:-/data}"
disk="${KVM_POOL_PATH:-/data/libvirt/images}/${name}.qcow2"

[[ "$(findmnt -n -T "$data_mount" -o TARGET 2>/dev/null || true)" == "$data_mount" ]] || fail "$data_mount is not a dedicated mounted target"
[[ "$(findmnt -n -T "$data_mount" -o FSTYPE 2>/dev/null || true)" == "${KVM_DATA_FSTYPE:-ext4}" ]] || fail "$data_mount must be ${KVM_DATA_FSTYPE:-ext4}"
sudo virsh --connect "$uri" pool-info "$pool" >/dev/null || fail "libvirt pool missing: $pool"
sudo virsh --connect "$uri" net-info "$network" >/dev/null || fail "libvirt network missing: $network"
sudo virsh --connect "$uri" dominfo "$name" >/dev/null 2>&1 && fail "domain already exists: $name"
[[ ! -e "$disk" ]] || fail "disk already exists: $disk"

sudo qemu-img create -f "${WINDOWS11_DISK_FORMAT:-qcow2}" "$disk" "${WINDOWS11_DISK_GB:-128}G"
sudo restorecon "$disk" 2>/dev/null || true

sudo virt-install \
  --connect "$uri" \
  --name "$name" \
  --memory "${WINDOWS11_RAM_MB:-12288}" \
  --vcpus "${WINDOWS11_VCPU:-4}" \
  --cpu "${WINDOWS11_CPU_MODE:-host-passthrough}" \
  --machine "${WINDOWS11_MACHINE:-q35}" \
  --features smm.state=on \
  --boot "uefi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=yes,firmware.feature1.name=enrolled-keys,firmware.feature1.enabled=yes" \
  --tpm "backend.type=emulator,backend.version=${WINDOWS11_TPM_VERSION:-2.0},model=tpm-crb" \
  --disk "path=${disk},format=${WINDOWS11_DISK_FORMAT:-qcow2},bus=${WINDOWS11_DISK_BUS:-virtio},discard=unmap" \
  --cdrom "$windows_iso" \
  --disk "path=${virtio_iso},device=cdrom,readonly=on" \
  --network "network=${network},model=${WINDOWS11_NETWORK_MODEL:-virtio}" \
  --graphics "${WINDOWS11_GRAPHICS:-spice}" \
  --video "${WINDOWS11_VIDEO:-virtio}" \
  --osinfo detect=on,require=off \
  --noautoconsole

printf '\nCreated %s. It is NOT configured for autostart.\n' "$name"
printf 'Open the graphical installer with: virt-manager --connect %s\n' "$uri"
printf 'During Windows Setup, load storage/network drivers from virtio-win.iso when requested.\n'

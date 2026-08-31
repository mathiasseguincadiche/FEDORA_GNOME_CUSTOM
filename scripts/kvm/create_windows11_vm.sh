#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/config/virtualization.conf"
source "$REPO_ROOT/config/hardware-components.conf"
source "$REPO_ROOT/config/vm-profiles.conf"

usage() {
  cat <<'TXT'
Usage:
  create_windows11_vm.sh \
    --windows-iso /path/to/windows11.iso \
    --virtio-iso /path/to/virtio-win.iso \
    [--windows-sha256 <trusted-sha256>] \
    [--virtio-sha256 <trusted-sha256>]

When hashes are supplied, both media files are verified before any VM disk is
created. The expected hashes must come from a trusted publisher/source; a hash
invented locally does not establish provenance.
TXT
}

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"; }

verify_sha256() {
  local file="$1" expected="$2" label="$3" actual
  [[ "$expected" =~ ^[0-9A-Fa-f]{64}$ ]] || fail "$label SHA-256 is not a 64-character hexadecimal digest"
  actual="$(sha256sum "$file" | awk '{print $1}')"
  [[ "${actual,,}" == "${expected,,}" ]] || fail "$label SHA-256 mismatch: expected=$expected actual=$actual"
  printf 'OK: %s SHA-256 verified (%s)\n' "$label" "$actual"
}

windows_iso=""
virtio_iso=""
windows_sha256=""
virtio_sha256=""

while (($#)); do
  case "$1" in
    --windows-iso) windows_iso="${2:-}"; shift 2 ;;
    --virtio-iso) virtio_iso="${2:-}"; shift 2 ;;
    --windows-sha256) windows_sha256="${2:-}"; shift 2 ;;
    --virtio-sha256) virtio_sha256="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -r "$windows_iso" ]] || { usage; fail 'valid --windows-iso is required'; }
[[ -r "$virtio_iso" ]] || { usage; fail 'valid --virtio-iso is required'; }

for cmd in virsh virt-install qemu-img findmnt xorriso restorecon sha256sum; do
  need "$cmd"
done

if [[ -n "$windows_sha256" || -n "$virtio_sha256" ]]; then
  [[ -n "$windows_sha256" && -n "$virtio_sha256" ]] \
    || fail 'provide both --windows-sha256 and --virtio-sha256, or neither'
  verify_sha256 "$windows_iso" "$windows_sha256" 'Windows ISO'
  verify_sha256 "$virtio_iso" "$virtio_sha256" 'VirtIO ISO'
else
  warn 'Windows/VirtIO SHA-256 values were not supplied; media provenance remains an explicit operator responsibility'
fi

uri="${LIBVIRT_URI:-qemu:///system}"
pool="${KVM_POOL_NAME:-devops-data}"
network="${KVM_NETWORK_NAME:-devops-nat}"
name="${WINDOWS11_NAME:-windows-11}"
data_mount="${KVM_DATA_MOUNT:-/data}"
disk="${KVM_POOL_PATH:-/data/libvirt/images}/${name}.qcow2"
smb_source="$REPO_ROOT/${WINDOWS11_SMB_SETUP_SCRIPT:-guest/windows-11/configure-smb-share.ps1}"
integration_source="$REPO_ROOT/${WINDOWS11_INTEGRATION_SCRIPT:-guest/windows-11/configure-guest-integration.ps1}"
tools_iso="${data_mount}/libvirt/iso/${WINDOWS11_GUEST_TOOLS_ISO_NAME:-windows-guest-tools.iso}"
nautilus_helper="$REPO_ROOT/scripts/kvm/configure_nautilus_vm_access.sh"

[[ "$(findmnt -n -T "$data_mount" -o TARGET 2>/dev/null || true)" == "$data_mount" ]] \
  || fail "$data_mount is not a dedicated mounted target"
[[ "$(findmnt -n -T "$data_mount" -o FSTYPE 2>/dev/null || true)" == "${KVM_DATA_FSTYPE:-ext4}" ]] \
  || fail "$data_mount must be ${KVM_DATA_FSTYPE:-ext4}"
[[ -r "$smb_source" && -r "$integration_source" ]] || fail 'Windows integration scripts missing'

sudo virsh --connect "$uri" pool-info "$pool" >/dev/null || fail "libvirt pool missing: $pool"
sudo virsh --connect "$uri" net-info "$network" >/dev/null || fail "libvirt network missing: $network"
sudo virsh --connect "$uri" dominfo "$name" >/dev/null 2>&1 && fail "domain already exists: $name"
[[ ! -e "$disk" ]] || fail "disk already exists: $disk"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT
install -d -m 0755 "$tmpdir/tools"
install -m 0644 "$smb_source" "$tmpdir/tools/Configure-VMShare.ps1"
install -m 0644 "$integration_source" "$tmpdir/tools/Configure-GuestIntegration.ps1"
printf '%s\n' 'Run Configure-GuestIntegration.ps1 as Administrator first, then Configure-VMShare.ps1 if SMB access from Nautilus is desired.' >"$tmpdir/tools/README.txt"

xorriso -as mkisofs -J -R -V FGC_TOOLS -o "$tmpdir/windows-guest-tools.iso" "$tmpdir/tools" >/dev/null 2>&1
sudo install -d -m 0755 "$(dirname "$tools_iso")"
sudo install -m 0644 "$tmpdir/windows-guest-tools.iso" "$tools_iso"
sudo restorecon "$tools_iso" 2>/dev/null || true

sudo qemu-img create -f "${WINDOWS11_DISK_FORMAT:-qcow2}" "$disk" "${WINDOWS11_DISK_GB:-128}G"
sudo restorecon "$disk" 2>/dev/null || true

io_state="${KVM_IO_PROFILE_STATE:-$HOME/.local/state/fedora-gnome-custom/kvm-io-profile.env}"
[[ -r "$io_state" ]] && source "$io_state"
disk_io="${KVM_IO_SELECTED_PROFILE:-${VM_DISK_IO_DEFAULT:-io_uring}}"
disk_help="$(virt-install --disk=? 2>&1 || true)"
disk_opts="path=${disk},format=${WINDOWS11_DISK_FORMAT:-qcow2},bus=${WINDOWS11_DISK_BUS:-virtio},cache=${VM_DISK_CACHE_MODE:-none},driver.io=${disk_io},driver.discard=${VM_DISK_DISCARD:-unmap}"
grep -Fq 'driver.detect_zeroes' <<<"$disk_help" && disk_opts+=",driver.detect_zeroes=${VM_DISK_DETECT_ZEROES:-unmap}"

extra_iothread=()
if virt-install --help 2>&1 | grep -q -- '--iothreads' && grep -Fq 'driver.iothread' <<<"$disk_help"; then
  extra_iothread=(--iothreads "${VM_IOTHREADS:-1}")
  disk_opts+=",driver.iothread=1"
fi

sudo virt-install \
  --connect "$uri" \
  --name "$name" \
  --memory "${WINDOWS11_RAM_MB:-12288}" \
  --vcpus "${WINDOWS11_VCPU:-4}" \
  --cpu "${WINDOWS11_CPU_MODE:-host-passthrough}" \
  --machine "${WINDOWS11_MACHINE:-q35}" \
  "${extra_iothread[@]}" \
  --features smm.state=on \
  --boot "uefi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=yes,firmware.feature1.name=enrolled-keys,firmware.feature1.enabled=yes" \
  --tpm "backend.type=emulator,backend.version=${WINDOWS11_TPM_VERSION:-2.0},model=tpm-crb" \
  --disk "$disk_opts" \
  --cdrom "$windows_iso" \
  --disk "path=${virtio_iso},device=cdrom,readonly=on" \
  --disk "path=${tools_iso},device=cdrom,readonly=on" \
  --network "network=${network},model=${WINDOWS11_NETWORK_MODEL:-virtio}" \
  --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 \
  --channel spicevmc,target.type=virtio,target.name=com.redhat.spice.0 \
  --rng /dev/urandom \
  --memballoon virtio \
  --graphics "${WINDOWS11_GRAPHICS:-spice}" \
  --video "${WINDOWS11_VIDEO:-virtio}" \
  --osinfo detect=on,require=off \
  --noautoconsole

printf '\nCreated %s with disk I/O profile %s. Install VirtIO drivers, then run Configure-GuestIntegration.ps1 from FGC_TOOLS.\n' "$name" "$disk_io"
if [[ "${VM_NAUTILUS_ACCESS_ENABLED:-true}" == true && -r "$nautilus_helper" ]]; then
  bash "$nautilus_helper" install || true
fi

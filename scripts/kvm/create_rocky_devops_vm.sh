#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/config/virtualization.conf"
source "$REPO_ROOT/config/hardware-components.conf"
source "$REPO_ROOT/config/vm-profiles.conf"

usage() {
  cat <<'TXT'
Usage:
  create_rocky_devops_vm.sh \
    --cloud-image /path/to/Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2 \
    [--ssh-key /path/to/key.pub] \
    [--sha256sums /path/to/CHECKSUM] \
    [--signature /path/to/CHECKSUM.asc] \
    [--rocky-key-file /path/to/RPM-GPG-KEY-Rocky-10]

When cloud-image verification is required, CHECKSUM and CHECKSUM.asc default
to files next to the image. The signed checksum list is authenticated before the
VM disk is created.
TXT
}

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"; }

cloud_image=""
ssh_key="${ROCKY_SERVER_SSH_PUBLIC_KEY_PATH:-${HOME}/.ssh/id_ed25519.pub}"
sha256sums=""
signature=""
rocky_key_file=""

while (($#)); do
  case "$1" in
    --cloud-image) cloud_image="${2:-}"; shift 2 ;;
    --ssh-key) ssh_key="${2:-}"; shift 2 ;;
    --sha256sums) sha256sums="${2:-}"; shift 2 ;;
    --signature) signature="${2:-}"; shift 2 ;;
    --rocky-key-file) rocky_key_file="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$cloud_image" && -r "$cloud_image" ]] || { usage; fail 'valid --cloud-image is required'; }
[[ -r "$ssh_key" ]] || fail "SSH public key not readable: $ssh_key"

for cmd in virsh virt-install qemu-img cloud-localds openssl base64 findmnt restorecon ssh-keygen python3; do
  need "$cmd"
done

[[ "${ROCKY_SERVER_CLOUD_IMAGE_VERIFICATION_REQUIRED:-true}" == true ]] || fail 'Rocky image authentication cannot be disabled'
if [[ "${ROCKY_SERVER_CLOUD_IMAGE_VERIFICATION_REQUIRED:-true}" == true ]]; then
  verifier="$REPO_ROOT/scripts/kvm/verify_rocky_cloud_image.sh"
  [[ -r "$verifier" ]] || fail "cloud-image verifier missing: $verifier"
  image_dir="$(cd "$(dirname "$cloud_image")" && pwd)"
  [[ -n "$sha256sums" ]] || sha256sums="$image_dir/${ROCKY_SERVER_CLOUD_IMAGE_SUMS_FILENAME:-CHECKSUM}"
  [[ -n "$signature" ]] || signature="$image_dir/${ROCKY_SERVER_CLOUD_IMAGE_SIGNATURE_FILENAME:-CHECKSUM.asc}"
  [[ -r "$sha256sums" ]] || fail "authenticated image policy requires readable CHECKSUM: $sha256sums"
  [[ -r "$signature" ]] || fail "authenticated image policy requires readable CHECKSUM.asc: $signature"

  verify_args=(
    --image "$cloud_image"
    --sha256sums "$sha256sums"
    --signature "$signature"
  )
  if [[ -n "$rocky_key_file" ]]; then
    [[ -r "$rocky_key_file" ]] || fail "Rocky key file not readable: $rocky_key_file"
    verify_args+=(--key-file "$rocky_key_file")
  fi
  bash "$verifier" "${verify_args[@]}" || fail 'Rocky cloud-image verification failed'
fi

uri="${LIBVIRT_URI:-qemu:///system}"
pool="${KVM_POOL_NAME:-devops-data}"
network="${KVM_NETWORK_NAME:-devops-nat}"
name="${ROCKY_SERVER_NAME:-rocky-devops}"
data_mount="${KVM_DATA_MOUNT:-/data}"
disk="${KVM_POOL_PATH:-/data/libvirt/images}/${name}.qcow2"
seed_dir="${data_mount}/libvirt/cloud-init/${name}"
seed="${seed_dir}/seed.iso"
username="${ROCKY_SERVER_USERNAME:-mathias}"
bootstrap="$REPO_ROOT/${ROCKY_SERVER_BOOTSTRAP_SCRIPT:-guest/rocky-devops/bootstrap-devops.sh}"
verify="$REPO_ROOT/${ROCKY_SERVER_VERIFY_SCRIPT:-guest/rocky-devops/verify-devops.sh}"
nautilus_helper="$REPO_ROOT/scripts/kvm/configure_nautilus_vm_access.sh"

[[ "$(findmnt -n -T "$data_mount" -o TARGET 2>/dev/null || true)" == "$data_mount" ]] \
  || fail "$data_mount is not a dedicated mounted target"
[[ "$(findmnt -n -T "$data_mount" -o FSTYPE 2>/dev/null || true)" == "${KVM_DATA_FSTYPE:-ext4}" ]] \
  || fail "$data_mount must be ${KVM_DATA_FSTYPE:-ext4}"

sudo virsh --connect "$uri" pool-info "$pool" >/dev/null || fail "libvirt pool missing: $pool"
sudo virsh --connect "$uri" net-info "$network" >/dev/null || fail "libvirt network missing: $network"
sudo virsh --connect "$uri" dominfo "$name" >/dev/null 2>&1 && fail "domain already exists: $name"
[[ ! -e "$disk" ]] || fail "disk already exists: $disk"
[[ ! -e "$seed_dir" ]] || fail "cloud-init seed directory already exists: $seed_dir"
[[ "$name" == rocky-devops && "${ROCKY_SERVER_RELEASE:-}" == 10.2 ]] || fail 'only the Rocky Linux 10.2 rocky-devops profile is supported'
[[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]] || fail 'invalid guest username'
ssh-keygen -l -f "$ssh_key" >/dev/null || fail 'invalid SSH public key'
# Conversion must never follow an unexpected external qcow2 backing file.
qemu-img info --output=json "$cloud_image" | python3 -c 'import json,sys; i=json.load(sys.stdin); assert i.get("format")=="qcow2" and not i.get("backing-filename")'
qemu-img check "$cloud_image"

read -rsp "Password for ${username} (console/sudo only; SSH password auth stays disabled): " guest_password
printf '\n'
[[ -n "$guest_password" ]] || fail 'empty password refused'
password_hash="$(openssl passwd -6 -stdin <<<"$guest_password")"
unset guest_password

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

ssh_public_key="$(awk 'NF >= 2 {print $1" "$2; exit}' "$ssh_key")"
[[ "$ssh_public_key" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521))[[:space:]][A-Za-z0-9+/]+=*$ ]] || fail 'provide one plain OpenSSH public key without authorized_keys options'
bootstrap_b64="$(base64 -w0 "$bootstrap")"
verify_b64="$(base64 -w0 "$verify")"
service_b64="$(base64 -w0 "$REPO_ROOT/guest/rocky-devops/devops-bootstrap.service")"

cat >"$tmpdir/user-data" <<EOF
#cloud-config
hostname: ${name}
manage_etc_hosts: true
ssh_pwauth: false
disable_root: true
users:
  - name: ${username}
    groups: [wheel]
    sudo: ALL=(ALL) ALL
    shell: /bin/bash
    lock_passwd: false
    passwd: '${password_hash}'
    ssh_authorized_keys: ['${ssh_public_key}']
write_files:
  - path: /usr/local/sbin/devops-bootstrap.sh
    permissions: '0755'
    encoding: b64
    content: ${bootstrap_b64}
  - path: /usr/local/sbin/devops-verify.sh
    permissions: '0755'
    encoding: b64
    content: ${verify_b64}
  - path: /etc/systemd/system/fgc-devops-bootstrap.service
    permissions: '0644'
    encoding: b64
    content: ${service_b64}
  - path: /etc/fgc-devops-bootstrap.env
    permissions: '0600'
    content: |
      DEVOPS_USER=${username}
runcmd:
  - [ systemctl, daemon-reload ]
  - [ systemctl, enable, fgc-devops-bootstrap.service ]
  - [ systemctl, start, --no-block, fgc-devops-bootstrap.service ]
EOF
printf 'instance-id: %s-001\nlocal-hostname: %s\n' "$name" "$name" >"$tmpdir/meta-data"
cloud-localds "$tmpdir/seed.iso" "$tmpdir/user-data" "$tmpdir/meta-data"

sudo qemu-img convert -O "${ROCKY_SERVER_DISK_FORMAT:-qcow2}" "$cloud_image" "$disk"
sudo qemu-img resize "$disk" "${ROCKY_SERVER_DISK_GB:-160}G"
sudo restorecon "$disk"
sudo install -d -m 0755 "$seed_dir"
sudo install -m 0644 "$tmpdir/seed.iso" "$seed"
sudo restorecon -R "$seed_dir"

io_state="${KVM_IO_PROFILE_STATE:-$HOME/.local/state/fedora-gnome-custom/kvm-io-profile.env}"
disk_io=""
[[ -r "$io_state" ]] && disk_io="$(awk -F= '$1=="KVM_IO_SELECTED_PROFILE" {print $2; exit}' "$io_state")"
case "$disk_io" in io_uring|native|threads) ;; *) disk_io="${VM_DISK_IO_DEFAULT:-io_uring}" ;; esac
disk_help="$(virt-install --disk=? 2>&1 || true)"
disk_opts="path=${disk},format=${ROCKY_SERVER_DISK_FORMAT:-qcow2},bus=${ROCKY_SERVER_DISK_BUS:-virtio},cache=${VM_DISK_CACHE_MODE:-none},driver.io=${disk_io},driver.discard=${VM_DISK_DISCARD:-unmap}"
grep -Fq 'driver.detect_zeroes' <<<"$disk_help" && disk_opts+=",driver.detect_zeroes=${VM_DISK_DETECT_ZEROES:-unmap}"

extra_iothread=()
if virt-install --help 2>&1 | grep -q -- '--iothreads' && grep -Fq 'driver.iothread' <<<"$disk_help"; then
  extra_iothread=(--iothreads "${VM_IOTHREADS:-1}")
  disk_opts+=",driver.iothread=1"
fi

sudo virt-install \
  --connect "$uri" \
  --name "$name" \
  --memory "${ROCKY_SERVER_RAM_MB:-16384}" \
  --vcpus "${ROCKY_SERVER_VCPU:-6}" \
  --cpu "${ROCKY_SERVER_CPU_MODE:-host-passthrough}" \
  --machine "${ROCKY_SERVER_MACHINE:-q35}" \
  "${extra_iothread[@]}" \
  --import \
  --boot uefi \
  --disk "$disk_opts" \
  --disk "path=${seed},device=cdrom,readonly=on" \
  --network "network=${network},model=${ROCKY_SERVER_NETWORK_MODEL:-virtio}" \
  --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 \
  --rng /dev/urandom \
  --memballoon virtio \
  --graphics none \
  --console pty,target.type=serial \
  --osinfo detect=on,require=off \
  --noautoconsole

printf '\nCreated %s with disk I/O profile %s. No autostart.\n' "$name" "$disk_io"
printf 'Rocky image authenticity was verified before disk creation.\n'
printf 'Guest filesystem access from Fedora remains SSH/SFTP through Nautilus/GIO; SSH authentication is key-only.\n'
if [[ "${VM_NAUTILUS_ACCESS_ENABLED:-true}" == true && -r "$nautilus_helper" ]]; then
  bash "$nautilus_helper" install || true
fi
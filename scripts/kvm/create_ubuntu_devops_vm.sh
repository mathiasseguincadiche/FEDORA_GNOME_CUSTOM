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
  create_ubuntu_devops_vm.sh --cloud-image /path/to/ubuntu-26.04-server-cloudimg-amd64.img [--ssh-key /path/to/key.pub]

The script never downloads an Ubuntu image and never stores a clear-text password in Git.
It creates ubuntu-devops explicitly; workstation APPLY never creates guests automatically.
EOF
}

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"; }

cloud_image=""
ssh_key="${UBUNTU_SERVER_SSH_PUBLIC_KEY_PATH:-${HOME}/.ssh/id_ed25519.pub}"

while (($#)); do
  case "$1" in
    --cloud-image) cloud_image="${2:-}"; shift 2 ;;
    --ssh-key) ssh_key="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -n "$cloud_image" ]] || { usage; fail '--cloud-image is required'; }
[[ -r "$cloud_image" ]] || fail "cloud image not readable: $cloud_image"
[[ -r "$ssh_key" ]] || fail "SSH public key not readable: $ssh_key"

for cmd in virsh virt-install qemu-img cloud-localds openssl base64 findmnt restorecon; do need "$cmd"; done

uri="${LIBVIRT_URI:-qemu:///system}"
pool="${KVM_POOL_NAME:-devops-data}"
network="${KVM_NETWORK_NAME:-devops-nat}"
name="${UBUNTU_SERVER_NAME:-ubuntu-devops}"
data_mount="${KVM_DATA_MOUNT:-/data}"
disk="${KVM_POOL_PATH:-/data/libvirt/images}/${name}.qcow2"
seed_dir="${data_mount}/libvirt/cloud-init/${name}"
seed="${seed_dir}/seed.iso"
share="${UBUNTU_SERVER_VIRTIOFS_SOURCE:-/data/libvirt/shared}"
share_tag="${UBUNTU_SERVER_VIRTIOFS_TAG:-hostshare}"
share_mount="${UBUNTU_SERVER_VIRTIOFS_MOUNT:-/mnt/hostshare}"
username="${UBUNTU_SERVER_USERNAME:-mathias}"
bootstrap="$REPO_ROOT/${UBUNTU_SERVER_BOOTSTRAP_SCRIPT:-guest/ubuntu-devops/bootstrap-devops.sh}"
verify="$REPO_ROOT/${UBUNTU_SERVER_VERIFY_SCRIPT:-guest/ubuntu-devops/verify-devops.sh}"

[[ "$(findmnt -n -T "$data_mount" -o TARGET 2>/dev/null || true)" == "$data_mount" ]] || fail "$data_mount is not a dedicated mounted target"
[[ "$(findmnt -n -T "$data_mount" -o FSTYPE 2>/dev/null || true)" == "${KVM_DATA_FSTYPE:-ext4}" ]] || fail "$data_mount must be ${KVM_DATA_FSTYPE:-ext4}"
sudo virsh --connect "$uri" pool-info "$pool" >/dev/null || fail "libvirt pool missing: $pool"
sudo virsh --connect "$uri" net-info "$network" >/dev/null || fail "libvirt network missing: $network"
sudo virsh --connect "$uri" dominfo "$name" >/dev/null 2>&1 && fail "domain already exists: $name"
[[ ! -e "$disk" ]] || fail "disk already exists: $disk"
[[ -r "$bootstrap" && -r "$verify" ]] || fail 'guest bootstrap/verification scripts missing'
[[ -d "$share" ]] || fail "VirtioFS source missing: $share"

read -rsp "Password for ${username} (entered only now; not committed to Git): " guest_password
printf '\n'
[[ -n "$guest_password" ]] || fail 'empty password refused'
password_hash="$(openssl passwd -6 -stdin <<<"$guest_password")"
unset guest_password

tmpdir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmpdir"
}
trap cleanup EXIT

ssh_public_key="$(awk 'NF >= 2 {print $1" "$2; exit}' "$ssh_key")"
[[ -n "$ssh_public_key" ]] || fail "invalid SSH public key: $ssh_key"
bootstrap_b64="$(base64 -w0 "$bootstrap")"
verify_b64="$(base64 -w0 "$verify")"

cat >"$tmpdir/user-data" <<EOF
#cloud-config
hostname: ${name}
manage_etc_hosts: true
ssh_pwauth: true
disable_root: true
users:
  - default
  - name: ${username}
    gecos: Mathias DevOps
    groups: [sudo]
    shell: /bin/bash
    lock_passwd: false
    passwd: '${password_hash}'
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - '${ssh_public_key}'
write_files:
  - path: /usr/local/sbin/devops-bootstrap.sh
    permissions: '0755'
    encoding: b64
    content: ${bootstrap_b64}
  - path: /usr/local/sbin/devops-verify.sh
    permissions: '0755'
    encoding: b64
    content: ${verify_b64}
runcmd:
  - [ bash, -lc, 'DEVOPS_USER=${username} VIRTIOFS_TAG=${share_tag} VIRTIOFS_MOUNT=${share_mount} /usr/local/sbin/devops-bootstrap.sh > /var/log/devops-bootstrap.log 2>&1' ]
final_message: 'ubuntu-devops cloud-init completed after \$UPTIME seconds'
EOF

cat >"$tmpdir/meta-data" <<EOF
instance-id: ${name}-001
local-hostname: ${name}
EOF

cloud-localds "$tmpdir/seed.iso" "$tmpdir/user-data" "$tmpdir/meta-data"

printf 'Creating disk %s from %s...\n' "$disk" "$cloud_image"
sudo qemu-img convert -O "${UBUNTU_SERVER_DISK_FORMAT:-qcow2}" "$cloud_image" "$disk"
sudo qemu-img resize "$disk" "${UBUNTU_SERVER_DISK_GB:-160}G"
sudo restorecon "$disk" 2>/dev/null || true

sudo install -d -m 0755 "$seed_dir"
sudo install -m 0644 "$tmpdir/seed.iso" "$seed"
sudo restorecon -R "$seed_dir" 2>/dev/null || true

sudo virt-install \
  --connect "$uri" \
  --name "$name" \
  --memory "${UBUNTU_SERVER_RAM_MB:-16384}" \
  --vcpus "${UBUNTU_SERVER_VCPU:-6}" \
  --cpu "${UBUNTU_SERVER_CPU_MODE:-host-passthrough}" \
  --machine "${UBUNTU_SERVER_MACHINE:-q35}" \
  --import \
  --boot uefi \
  --memorybacking source.type=memfd,access.mode=shared \
  --disk "path=${disk},format=${UBUNTU_SERVER_DISK_FORMAT:-qcow2},bus=${UBUNTU_SERVER_DISK_BUS:-virtio},discard=unmap" \
  --disk "path=${seed},device=cdrom,readonly=on" \
  --network "network=${network},model=${UBUNTU_SERVER_NETWORK_MODEL:-virtio}" \
  --filesystem "source=${share},target=${share_tag},driver.type=virtiofs,accessmode=passthrough" \
  --graphics none \
  --console pty,target.type=serial \
  --osinfo detect=on,require=off \
  --noautoconsole

printf '\nCreated %s. It is NOT configured for autostart.\n' "$name"
printf 'Wait for cloud-init/bootstrap, then discover its IP with:\n'
printf '  sudo virsh -c %s domifaddr %s --source agent\n' "$uri" "$name"
printf 'Then verify from the guest:\n'
printf '  sudo /usr/local/sbin/devops-verify.sh\n'

#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/config/virtualization.conf"
source "$REPO_ROOT/config/hardware-components.conf"
source "$REPO_ROOT/config/vm-profiles.conf"
usage(){ echo 'Usage: create_ubuntu_devops_vm.sh --cloud-image /path/to/ubuntu-26.04-server-cloudimg-amd64.img [--ssh-key /path/to/key.pub]'; }
fail(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"; }
cloud_image=""; ssh_key="${UBUNTU_SERVER_SSH_PUBLIC_KEY_PATH:-${HOME}/.ssh/id_ed25519.pub}"
while (($#)); do case "$1" in --cloud-image) cloud_image="${2:-}"; shift 2;; --ssh-key) ssh_key="${2:-}"; shift 2;; -h|--help) usage; exit 0;; *) fail "unknown argument: $1";; esac; done
[[ -n "$cloud_image" && -r "$cloud_image" ]] || { usage; fail 'valid --cloud-image is required'; }
[[ -r "$ssh_key" ]] || fail "SSH public key not readable: $ssh_key"
for cmd in virsh virt-install qemu-img cloud-localds openssl base64 findmnt restorecon; do need "$cmd"; done
uri="${LIBVIRT_URI:-qemu:///system}"; pool="${KVM_POOL_NAME:-devops-data}"; network="${KVM_NETWORK_NAME:-devops-nat}"; name="${UBUNTU_SERVER_NAME:-ubuntu-devops}"; data_mount="${KVM_DATA_MOUNT:-/data}"
disk="${KVM_POOL_PATH:-/data/libvirt/images}/${name}.qcow2"; seed_dir="${data_mount}/libvirt/cloud-init/${name}"; seed="${seed_dir}/seed.iso"; username="${UBUNTU_SERVER_USERNAME:-mathias}"
bootstrap="$REPO_ROOT/${UBUNTU_SERVER_BOOTSTRAP_SCRIPT:-guest/ubuntu-devops/bootstrap-devops.sh}"; verify="$REPO_ROOT/${UBUNTU_SERVER_VERIFY_SCRIPT:-guest/ubuntu-devops/verify-devops.sh}"; nautilus_helper="$REPO_ROOT/scripts/kvm/configure_nautilus_vm_access.sh"
[[ "$(findmnt -n -T "$data_mount" -o TARGET 2>/dev/null || true)" == "$data_mount" ]] || fail "$data_mount is not a dedicated mounted target"
[[ "$(findmnt -n -T "$data_mount" -o FSTYPE 2>/dev/null || true)" == "${KVM_DATA_FSTYPE:-ext4}" ]] || fail "$data_mount must be ${KVM_DATA_FSTYPE:-ext4}"
sudo virsh --connect "$uri" pool-info "$pool" >/dev/null || fail "libvirt pool missing: $pool"; sudo virsh --connect "$uri" net-info "$network" >/dev/null || fail "libvirt network missing: $network"
sudo virsh --connect "$uri" dominfo "$name" >/dev/null 2>&1 && fail "domain already exists: $name"; [[ ! -e "$disk" ]] || fail "disk already exists: $disk"
read -rsp "Password for ${username} (console/sudo only; SSH password auth stays disabled): " guest_password; printf '\n'; [[ -n "$guest_password" ]] || fail 'empty password refused'; password_hash="$(openssl passwd -6 -stdin <<<"$guest_password")"; unset guest_password
tmpdir="$(mktemp -d)"; cleanup(){ rm -rf "$tmpdir"; }; trap cleanup EXIT
ssh_public_key="$(awk 'NF >= 2 {print $1" "$2; exit}' "$ssh_key")"; bootstrap_b64="$(base64 -w0 "$bootstrap")"; verify_b64="$(base64 -w0 "$verify")"
cat >"$tmpdir/user-data" <<EOF
#cloud-config
hostname: ${name}
manage_etc_hosts: true
ssh_pwauth: false
disable_root: true
users:
  - default
  - name: ${username}
    groups: [sudo]
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
runcmd:
  - [ bash, -lc, 'DEVOPS_USER=${username} /usr/local/sbin/devops-bootstrap.sh > /var/log/devops-bootstrap.log 2>&1' ]
EOF
printf 'instance-id: %s-001\nlocal-hostname: %s\n' "$name" "$name" > "$tmpdir/meta-data"; cloud-localds "$tmpdir/seed.iso" "$tmpdir/user-data" "$tmpdir/meta-data"
sudo qemu-img convert -O "${UBUNTU_SERVER_DISK_FORMAT:-qcow2}" "$cloud_image" "$disk"; sudo qemu-img resize "$disk" "${UBUNTU_SERVER_DISK_GB:-160}G"; sudo restorecon "$disk" 2>/dev/null || true
sudo install -d -m 0755 "$seed_dir"; sudo install -m 0644 "$tmpdir/seed.iso" "$seed"; sudo restorecon -R "$seed_dir" 2>/dev/null || true
io_state="${KVM_IO_PROFILE_STATE:-$HOME/.local/state/fedora-gnome-custom/kvm-io-profile.env}"; [[ -r "$io_state" ]] && source "$io_state"
disk_io="${KVM_IO_SELECTED_PROFILE:-${VM_DISK_IO_DEFAULT:-io_uring}}"; disk_help="$(virt-install --disk=? 2>&1 || true)"
disk_opts="path=${disk},format=${UBUNTU_SERVER_DISK_FORMAT:-qcow2},bus=${UBUNTU_SERVER_DISK_BUS:-virtio},cache=${VM_DISK_CACHE_MODE:-none},driver.io=${disk_io},driver.discard=${VM_DISK_DISCARD:-unmap}"
grep -Fq 'driver.detect_zeroes' <<<"$disk_help" && disk_opts+=",driver.detect_zeroes=${VM_DISK_DETECT_ZEROES:-unmap}"
extra_iothread=(); if virt-install --help 2>&1 | grep -q -- '--iothreads' && grep -Fq 'driver.iothread' <<<"$disk_help"; then extra_iothread=(--iothreads "${VM_IOTHREADS:-1}"); disk_opts+=",driver.iothread=1"; fi
sudo virt-install --connect "$uri" --name "$name" --memory "${UBUNTU_SERVER_RAM_MB:-16384}" --vcpus "${UBUNTU_SERVER_VCPU:-6}" --cpu "${UBUNTU_SERVER_CPU_MODE:-host-passthrough}" --machine "${UBUNTU_SERVER_MACHINE:-q35}" "${extra_iothread[@]}" --import --boot uefi --disk "$disk_opts" --disk "path=${seed},device=cdrom,readonly=on" --network "network=${network},model=${UBUNTU_SERVER_NETWORK_MODEL:-virtio}" --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 --rng /dev/urandom --memballoon virtio --graphics none --console pty,target.type=serial --osinfo detect=on,require=off --noautoconsole
printf '\nCreated %s with disk I/O profile %s. No autostart.\n' "$name" "$disk_io"
printf 'Guest filesystem access from Fedora remains SSH/SFTP through Nautilus/GIO; SSH authentication is key-only.\n'
if [[ "${VM_NAUTILUS_ACCESS_ENABLED:-true}" == true && -r "$nautilus_helper" ]]; then bash "$nautilus_helper" install || true; fi

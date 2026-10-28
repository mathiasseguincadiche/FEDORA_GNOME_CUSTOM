#!/usr/bin/env bash
# Real scripts/kvm/create_rocky_devops_vm.sh run in a repository copy with fake
# libvirt/qemu/cloud-localds: the image is authenticated before any disk is
# made, the cloud-init seed gives key-only SSH, a hashed password and sudo
# with password, it ships the exact guest scripts, and every unsafe input is
# refused before the disk. The guest itself is exercised by the real Rocky lab
# (.github/workflows/vm-pretest.yml).
# shellcheck disable=SC2016,SC2119,SC2120
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "rocky vm creation behavior: FAIL: $*" >&2; exit 1; }

fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/data/libvirt/images" "$tmp/iso" "$tmp/home"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home" T_LOG="$tmp/calls" T_TMP="$tmp"
sed -i "s|^KVM_DATA_MOUNT=.*|KVM_DATA_MOUNT=\"$tmp/data\"|; s|^KVM_POOL_PATH=.*|KVM_POOL_PATH=\"$tmp/data/libvirt/images\"|" \
  "$fixture/config/virtualization.conf"
cat >> "$fixture/lib/persistent_data.sh" <<'SH'
persistent_data_validate_mount_at() { [[ "${T_DATA:-valid}" == valid ]]; }
SH
cat > "$fixture/scripts/kvm/verify_rocky_cloud_image.sh" <<'SH'
printf 'verify %s\n' "$*" >> "$T_LOG"
exit "${T_VERIFY_RC:-0}"
SH
cat > "$fixture/scripts/kvm/configure_nautilus_vm_access.sh" <<'SH'
printf 'nautilus %s\n' "$*" >> "$T_LOG"
SH

recorder() { printf '#!/usr/bin/env bash\nprintf "%s %%s\\n" "$*" >> "$T_LOG"\n%s\n' "$1" "${2:-}" > "$tmp/bin/$1"; }
recorder sudo 'exec "$@"'
recorder virsh '[[ "$*" != *dominfo* ]]'
recorder virt-install
recorder restorecon
recorder qemu-img 'case "$1" in info) echo "{\"format\": \"qcow2\"}" ;; convert) touch "${@: -1}" ;; esac'
recorder cloud-localds 'cp "$2" "$T_TMP/user-data"; touch "$1"'
recorder findmnt 'case "$*" in *TARGET*) echo "$T_TMP/data" ;; *FSTYPE*) echo ext4 ;; esac'
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"

image="$tmp/iso/Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2"
touch "$image" "$tmp/iso/CHECKSUM" "$tmp/iso/CHECKSUM.asc"
ssh-keygen -q -t ed25519 -N '' -C fixture -f "$tmp/key"
password='S3cret-console-pass'

create() {
  rm -f "$T_LOG" "$tmp/user-data"; rm -rf "$tmp/data/libvirt/cloud-init" "$tmp/data/libvirt/images/rocky-devops.qcow2"
  printf '%s\n' "${T_PASSWORD-$password}" | bash "$fixture/scripts/kvm/create_rocky_devops_vm.sh" \
    --cloud-image "$image" --ssh-key "${T_KEY:-$tmp/key.pub}" "$@" > "$tmp/out" 2>&1
}
no_disk() {
  if grep -Eq '^(qemu-img convert|virt-install)' "$T_LOG" 2>/dev/null; then fail "$1: a disk or domain was created"; fi
}

create || { cat "$tmp/out" >&2; fail 'VM creation failed'; }

# The signed CHECKSUM next to the image is verified before the disk exists.
order="$(grep -nE '^(verify|qemu-img convert|virt-install)' "$T_LOG" | cut -d' ' -f1 | tr '\n' ' ')"
[[ "$order" == '1:verify '*'qemu-img '*'virt-install '* ]] || fail "unexpected creation order: $order"
grep -Fxq "verify --image $image --sha256sums $tmp/iso/CHECKSUM --signature $tmp/iso/CHECKSUM.asc" "$T_LOG" \
  || fail 'image not verified against the CHECKSUM files next to it'

# cloud-init: key-only SSH, no root, sudo with password, hashed password.
seed="$tmp/user-data"
for line in 'ssh_pwauth: false' 'disable_root: true' '    sudo: ALL=(ALL) ALL'; do
  grep -Fxq "$line" "$seed" || fail "cloud-init lacks: $line"
done
if grep -Fq NOPASSWD "$seed"; then fail 'passwordless sudo provisioned'; fi
if grep -Fq "$password" "$seed" "$T_LOG"; then fail 'clear-text password leaked'; fi
hash="$(sed -n "s/^    passwd: '\(.*\)'$/\1/p" "$seed")"
salt="$(cut -d'$' -f3 <<<"$hash")"
[[ "$hash" == '$6$'* && "$(openssl passwd -6 -salt "$salt" "$password")" == "$hash" ]] || fail 'password is not a SHA-512 crypt of the typed password'
grep -Fxq "    ssh_authorized_keys: ['$(cut -d' ' -f1,2 "$tmp/key.pub")']" "$seed" || fail 'SSH key not provisioned as a plain key'

# The guest receives the exact repository scripts.
python3 - "$seed" "$ROOT" <<'PY' || fail 'guest files differ from the repository'
import base64, pathlib, re, sys
seed, root = pathlib.Path(sys.argv[1]).read_text(), pathlib.Path(sys.argv[2])
files = dict(re.findall(r"- path: (\S+)\n(?:    .*\n)*?    content: (\S+)", seed))
expected = {
    "/usr/local/sbin/devops-bootstrap.sh": "guest/rocky-devops/bootstrap-devops.sh",
    "/usr/local/sbin/devops-verify.sh": "guest/rocky-devops/verify-devops.sh",
    "/usr/local/sbin/devops-verify-docker-network.sh": "guest/rocky-devops/verify-docker-network.sh",
    "/usr/local/sbin/devops-verify-bootstrap-marker.py": "guest/rocky-devops/verify-bootstrap-marker.py",
    "/etc/systemd/system/fgc-devops-bootstrap.service": "guest/rocky-devops/devops-bootstrap.service",
}
for path, source in expected.items():
    assert base64.b64decode(files[path]) == (root / source).read_bytes(), path
PY

# UEFI domain on the isolated network, never autostarted.
domain="$(grep '^virt-install ' "$T_LOG")"
grep -Fq -- '--network network=devops-nat,' <<<"$domain" || fail 'domain not on devops-nat'
grep -Fq -- '--boot uefi' <<<"$domain" || fail 'domain not UEFI'
if grep -Fq -- '--autostart' <<<"$domain"; then fail 'domain set to autostart'; fi

# Unsafe inputs are refused before any disk or domain.
rc=0; T_VERIFY_RC=1 create || rc=$?; [[ "$rc" != 0 ]] || fail 'unauthenticated image accepted'; no_disk 'failed verification'
# Machine overrides go through config/local.conf, which wins over the defaults.
override() {
  local want="$1" rc=0
  printf '%s\n' "$2" > "$fixture/config/local.conf"
  create || rc=$?
  rm -f "$fixture/config/local.conf"
  if [[ "$want" == accepted ]]; then
    [[ "$rc" == 0 ]] || { cat "$tmp/out" >&2; fail "harmless override refused: $2"; }
  else
    [[ "$rc" != 0 ]] || fail "accepted: $2"
    no_disk "$2"
  fi
}
override accepted 'ROCKY_SERVER_RAM_MB="8192"'
override refused 'ROCKY_SERVER_CLOUD_IMAGE_VERIFICATION_REQUIRED="false"'
override refused 'ROCKY_SERVER_USERNAME="Root;x"'
override refused 'ROCKY_SERVER_RELEASE="9.6"'
rc=0; T_PASSWORD='' create || rc=$?; [[ "$rc" != 0 ]] || fail 'empty password accepted'; no_disk 'empty password'
rc=0; T_DATA=invalid create || rc=$?; [[ "$rc" != 0 ]] || fail 'unproven /data accepted'; no_disk 'unproven /data'
printf 'command="/bin/true" %s\n' "$(cat "$tmp/key.pub")" > "$tmp/restricted.pub"
rc=0; T_KEY="$tmp/restricted.pub" create || rc=$?; [[ "$rc" != 0 ]] || fail 'key with options accepted'; no_disk 'key with options'
rm -f "$T_LOG"; touch "$tmp/data/libvirt/images/rocky-devops.qcow2"
rc=0
printf '%s\n' "$password" | bash "$fixture/scripts/kvm/create_rocky_devops_vm.sh" --cloud-image "$image" --ssh-key "$tmp/key.pub" > "$tmp/out" 2>&1 || rc=$?
[[ "$rc" != 0 ]] || fail 'existing disk overwritten'; no_disk 'existing disk'

echo 'rocky vm creation behavior: PASS'

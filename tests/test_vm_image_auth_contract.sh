#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
verifier="$ROOT/scripts/kvm/verify_ubuntu_cloud_image.sh"
ubuntu_create="$ROOT/scripts/kvm/create_ubuntu_devops_vm.sh"
windows_create="$ROOT/scripts/kvm/create_windows11_vm.sh"
profiles="$ROOT/config/vm-profiles.conf"
packages="$ROOT/manifests/packages-virtualization.txt"

for file in "$verifier" "$ubuntu_create" "$windows_create" "$profiles" "$packages"; do
  [[ -f "$file" ]] || { echo "missing VM image authentication file: $file" >&2; exit 1; }
done

# Canonical authenticity: signed checksum list + pinned fingerprint + image hash.
grep -Fq 'D2EB44626FDDC30B513D5BB71A5D6C4C7DB87C81' "$verifier"
grep -Fq -- "--verify \"\$signature\" \"\$sums\"" "$verifier"
grep -Fq "sha256sum \"\$image\"" "$verifier"
grep -Fq 'unexpected Canonical key fingerprint' "$verifier"
if grep -Eq 'curl[[:space:]].*\|[[:space:]]*(bash|sh)|wget[[:space:]].*\|[[:space:]]*(bash|sh)' "$verifier"; then
  echo 'cloud image verifier must not pipe network content to a shell' >&2
  exit 1
fi

# VM creation must require and invoke the verifier before qemu-img conversion.
grep -Fq 'UBUNTU_SERVER_CLOUD_IMAGE_VERIFICATION_REQUIRED="true"' "$profiles"
grep -Fq 'UBUNTU_SERVER_CLOUD_IMAGE_SUMS_FILENAME="SHA256SUMS"' "$profiles"
grep -Fq 'UBUNTU_SERVER_CLOUD_IMAGE_SIGNATURE_FILENAME="SHA256SUMS.gpg"' "$profiles"
grep -Fq 'verify_ubuntu_cloud_image.sh' "$ubuntu_create"
grep -Fq "bash \"\$verifier\"" "$ubuntu_create"
verify_line="$(grep -n "bash \"\$verifier\"" "$ubuntu_create" | cut -d: -f1 | head -n1)"
convert_line="$(grep -n 'qemu-img convert' "$ubuntu_create" | cut -d: -f1 | head -n1)"
[[ "$verify_line" =~ ^[0-9]+$ && "$convert_line" =~ ^[0-9]+$ && "$verify_line" -lt "$convert_line" ]] || {
  echo 'Ubuntu image verification must occur before qemu-img convert' >&2
  exit 1
}

grep -Fxq 'gnupg2' "$packages"

# Windows media hashes are optional because publisher ISO versions vary, but
# when supplied both files must be verified before disk creation.
grep -Fq -- '--windows-sha256' "$windows_create"
grep -Fq -- '--virtio-sha256' "$windows_create"
grep -Fq 'provide both --windows-sha256 and --virtio-sha256, or neither' "$windows_create"
grep -Fq "verify_sha256 \"\$windows_iso\"" "$windows_create"
grep -Fq "verify_sha256 \"\$virtio_iso\"" "$windows_create"
windows_verify_line="$(grep -n "verify_sha256 \"\$windows_iso\"" "$windows_create" | cut -d: -f1 | head -n1)"
windows_disk_line="$(grep -n 'qemu-img create' "$windows_create" | cut -d: -f1 | head -n1)"
[[ "$windows_verify_line" =~ ^[0-9]+$ && "$windows_disk_line" =~ ^[0-9]+$ && "$windows_verify_line" -lt "$windows_disk_line" ]] || {
  echo 'Windows media verification must occur before qemu-img create' >&2
  exit 1
}

echo 'VM image authentication contract: PASS'

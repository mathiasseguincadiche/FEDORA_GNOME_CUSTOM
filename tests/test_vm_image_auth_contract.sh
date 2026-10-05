#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
verifier="$ROOT/scripts/kvm/verify_rocky_cloud_image.sh"
rocky_create="$ROOT/scripts/kvm/create_rocky_devops_vm.sh"
windows_create="$ROOT/scripts/kvm/create_windows11_vm.sh"
profiles="$ROOT/config/vm-profiles.conf"
packages="$ROOT/manifests/packages-virtualization.txt"

for file in "$verifier" "$rocky_create" "$windows_create" "$profiles" "$packages"; do
  [[ -f "$file" ]] || { echo "missing VM image authentication file: $file" >&2; exit 1; }
done

# Rocky authenticity: signed checksum list + pinned fingerprint + image hash.
grep -Fq 'FC226859C0860BF0DDB95B085B106C736FEDFC85' "$verifier"
# shellcheck disable=SC2016
grep -Fq '"$signature" "$sums"' "$verifier"
grep -Fq "sha256sum \"\$image\"" "$verifier"
grep -Fq 'unexpected Rocky key fingerprint' "$verifier"
if grep -Eq 'curl[[:space:]].*\|[[:space:]]*(bash|sh)|wget[[:space:]].*\|[[:space:]]*(bash|sh)' "$verifier"; then
  echo 'cloud image verifier must not pipe network content to a shell' >&2
  exit 1
fi

# VM creation must require and invoke the verifier before qemu-img conversion.
grep -Fq 'ROCKY_SERVER_CLOUD_IMAGE_VERIFICATION_REQUIRED="true"' "$profiles"
grep -Fq 'ROCKY_SERVER_CLOUD_IMAGE_SUMS_FILENAME="CHECKSUM"' "$profiles"
grep -Fq 'ROCKY_SERVER_CLOUD_IMAGE_SIGNATURE_FILENAME="CHECKSUM.asc"' "$profiles"
grep -Fq 'verify_rocky_cloud_image.sh' "$rocky_create"
grep -Fq "bash \"\$verifier\"" "$rocky_create"
verify_line="$(grep -n "bash \"\$verifier\"" "$rocky_create" | cut -d: -f1 | head -n1)"
convert_line="$(grep -n 'qemu-img convert' "$rocky_create" | cut -d: -f1 | head -n1)"
[[ "$verify_line" =~ ^[0-9]+$ && "$convert_line" =~ ^[0-9]+$ && "$verify_line" -lt "$convert_line" ]] || {
  echo 'Ubuntu image verification must occur before qemu-img convert' >&2
  exit 1
}
grep -Fxq 'gnupg2' "$packages"

# Windows and VirtIO publisher hashes are mandatory Golden inputs and both are
# verified before any qcow2 disk is created.
grep -Fq -- '--windows-sha256' "$windows_create"
grep -Fq -- '--virtio-sha256' "$windows_create"
grep -Fq 'trusted SHA-256 is mandatory for both Windows and VirtIO media' "$windows_create"
grep -Fq "verify_sha256 \"\$windows_iso\"" "$windows_create"
grep -Fq "verify_sha256 \"\$virtio_iso\"" "$windows_create"
if grep -Fq 'or neither' "$windows_create"; then
  echo 'Windows/VirtIO hashes must not be optional' >&2
  exit 1
fi
windows_verify_line="$(grep -n "verify_sha256 \"\$windows_iso\"" "$windows_create" | cut -d: -f1 | head -n1)"
windows_disk_line="$(grep -n 'qemu-img create' "$windows_create" | cut -d: -f1 | head -n1)"
[[ "$windows_verify_line" =~ ^[0-9]+$ && "$windows_disk_line" =~ ^[0-9]+$ && "$windows_verify_line" -lt "$windows_disk_line" ]] || {
  echo 'Windows media verification must occur before qemu-img create' >&2
  exit 1
}

echo 'VM image authentication contract: PASS'

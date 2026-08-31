#!/usr/bin/env bash
set -Eeuo pipefail

# Canonical documents this signing key for Ubuntu cloud-image SHA256SUMS.
# Source of truth: https://ubuntu.com/docs/public-images/public-images-how-to/verify-image-checksum/
CANONICAL_CLOUD_IMAGE_FINGERPRINT="D2EB44626FDDC30B513D5BB71A5D6C4C7DB87C81"
DEFAULT_KEYSERVER="hkps://keyserver.ubuntu.com"

usage() {
  cat <<'TXT'
Usage:
  verify_ubuntu_cloud_image.sh \
    --image /path/to/ubuntu-26.04-server-cloudimg-amd64.img \
    --sha256sums /path/to/SHA256SUMS \
    --signature /path/to/SHA256SUMS.gpg \
    [--key-file /path/to/canonical-cloud-image-signing-key.asc] \
    [--keyserver hkps://keyserver.ubuntu.com]

The script authenticates SHA256SUMS with Canonical's pinned cloud-image signing
fingerprint, then verifies the selected image against that authenticated list.
TXT
}

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"; }

image=""
sums=""
signature=""
key_file=""
keyserver="$DEFAULT_KEYSERVER"

while (($#)); do
  case "$1" in
    --image) image="${2:-}"; shift 2 ;;
    --sha256sums) sums="${2:-}"; shift 2 ;;
    --signature) signature="${2:-}"; shift 2 ;;
    --key-file) key_file="${2:-}"; shift 2 ;;
    --keyserver) keyserver="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -r "$image" ]] || { usage; fail 'readable --image is required'; }
[[ -r "$sums" ]] || { usage; fail 'readable --sha256sums is required'; }
[[ -r "$signature" ]] || { usage; fail 'readable --signature is required'; }
[[ -z "$key_file" || -r "$key_file" ]] || fail "key file is not readable: $key_file"

need gpg
need sha256sum
need awk
need mktemp

image_name="$(basename "$image")"
expected="$(awk -v name="$image_name" '
  NF >= 2 {
    file=$2
    sub(/^\*/, "", file)
    if (file == name) { print $1; exit }
  }
' "$sums")"
[[ "$expected" =~ ^[0-9A-Fa-f]{64}$ ]] || fail "$image_name is not present in SHA256SUMS with a valid SHA-256"

tmpdir="$(mktemp -d)"
chmod 0700 "$tmpdir"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

if [[ -n "$key_file" ]]; then
  gpg --homedir "$tmpdir" --batch --quiet --import "$key_file" >/dev/null 2>&1 \
    || fail 'unable to import the supplied Canonical key file'
else
  # Reuse a trusted local copy when the operator already imported the key.
  local_key="$tmpdir/local-key.gpg"
  if gpg --batch --export "$CANONICAL_CLOUD_IMAGE_FINGERPRINT" >"$local_key" 2>/dev/null && [[ -s "$local_key" ]]; then
    gpg --homedir "$tmpdir" --batch --quiet --import "$local_key" >/dev/null 2>&1 \
      || fail 'unable to import Canonical signing key from the local GnuPG keyring'
  else
    rm -f "$local_key"
    gpg --homedir "$tmpdir" --batch --keyserver "$keyserver" --recv-keys "$CANONICAL_CLOUD_IMAGE_FINGERPRINT" >/dev/null 2>&1 \
      || fail "unable to retrieve Canonical signing key from $keyserver; use --key-file for offline verification"
  fi
fi

actual_fingerprint="$(
  gpg --homedir "$tmpdir" --batch --with-colons --fingerprint "$CANONICAL_CLOUD_IMAGE_FINGERPRINT" 2>/dev/null \
    | awk -F: '$1=="fpr" {print toupper($10); exit}'
)"
[[ "$actual_fingerprint" == "$CANONICAL_CLOUD_IMAGE_FINGERPRINT" ]] \
  || fail "unexpected Canonical key fingerprint: ${actual_fingerprint:-missing}"

gpg --homedir "$tmpdir" --batch --verify "$signature" "$sums" >/dev/null 2>&1 \
  || fail 'SHA256SUMS signature verification failed'

actual="$(sha256sum "$image" | awk '{print $1}')"
[[ "${actual,,}" == "${expected,,}" ]] \
  || fail "image SHA-256 mismatch: expected=$expected actual=$actual"

printf 'Canonical cloud image verification: PASS\n'
printf 'image=%s\n' "$image_name"
printf 'sha256=%s\n' "$actual"
printf 'signer_fingerprint=%s\n' "$CANONICAL_CLOUD_IMAGE_FINGERPRINT"

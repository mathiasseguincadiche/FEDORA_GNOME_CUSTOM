#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -m 0700 "$tmp/keys"
export GNUPGHOME="$tmp/keys"
gpg --batch --passphrase '' --quick-generate-key 'Rocky fixture <rocky@example.invalid>' rsa2048 cert 0 >/dev/null 2>&1
pin="$(gpg --with-colons --list-keys 2>/dev/null | awk -F: '$1=="fpr"{print $10;exit}')"
gpg --batch --passphrase '' --quick-add-key "$pin" rsa2048 sign 0 >/dev/null 2>&1
gpg --batch --armor --export "$pin" >"$tmp/key.asc"
# Only the fixture copy gets its ephemeral key. Production has no pin override.
sed "s/FC226859C0860BF0DDB95B085B106C736FEDFC85/$pin/g" "$ROOT/scripts/kvm/verify_rocky_cloud_image.sh" >"$tmp/verify.sh"
name=Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2
printf 'fixture image\n' >"$tmp/$name"
hash="$(sha256sum "$tmp/$name" | awk '{print $1}')"
sign() { gpg --batch --yes --passphrase '' --local-user "$pin" --armor --detach-sign --output "$tmp/CHECKSUM.asc" "$tmp/CHECKSUM" >/dev/null 2>&1; }
verify() { bash "$tmp/verify.sh" --image "$tmp/$name" --sha256sums "$tmp/CHECKSUM" --signature "$tmp/CHECKSUM.asc" --key-file "$tmp/key.asc"; }
reject() { if verify >/dev/null 2>&1; then echo "unexpected acceptance: $*" >&2; exit 1; fi; }
printf 'SHA256 (%s) = %s\n' "$name" "$hash" >"$tmp/CHECKSUM"
sign
verify >/dev/null
printf '%s  %s\n' "$hash" "$name" >"$tmp/CHECKSUM"
sign
verify >/dev/null
printf 'tampered\n' >>"$tmp/$name"
reject 'tampered image'
printf 'fixture image\n' >"$tmp/$name"
printf '%s  %s\n%s  %s\n' "$hash" "$name" "$hash" "$name" >"$tmp/CHECKSUM"
sign
reject 'duplicate checksum identity'
printf '%s  another.qcow2\n%s  %s\n' "$hash" "$(printf '0%.0s' {1..64})" "$name" >"$tmp/CHECKSUM"
sign
reject 'hash and filename on unrelated rows'
printf '%s  %s\n' "$hash" "$name" >"$tmp/CHECKSUM"
sign
printf 'extra unsigned checksum\n' >>"$tmp/CHECKSUM"
reject 'modified signed list'
printf '%s  %s\n' "$hash" "$name" >"$tmp/CHECKSUM"
sign
gpg --batch --passphrase '' --quick-generate-key 'Wrong signer <wrong@example.invalid>' rsa2048 sign 0 >/dev/null 2>&1
wrong="$(gpg --with-colons --list-keys wrong@example.invalid 2>/dev/null | awk -F: '$1=="fpr"{print $10;exit}')"
gpg --batch --yes --passphrase '' --local-user "$wrong" --armor --detach-sign --output "$tmp/CHECKSUM.asc" "$tmp/CHECKSUM" >/dev/null 2>&1
gpg --batch --armor --export "$pin" "$wrong" >"$tmp/key.asc"
reject 'wrong signer bundled beside trusted key'
sign
mv "$tmp/$name" "$tmp/original"
ln -s "$tmp/original" "$tmp/$name"
reject 'symlink source image'
echo 'Rocky image authenticity behavior: PASS (valid signing subkey, GNU/BSD, tamper, duplicate, wrong signer, symlink)'

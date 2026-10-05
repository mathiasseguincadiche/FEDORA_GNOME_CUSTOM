#!/usr/bin/env bash
# Real signatures in a disposable fixture: reject another signing identity,
# unpaired checksum rows, modified ISO bytes and unsigned checksum data.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -m 700 "$tmp/keys"
mkdir "$tmp/installer"
cp "$ROOT/installer/verify-fedora44-media.sh" "$tmp/installer/"
for cmd in gpg gpgv python3 sha256sum; do command -v "$cmd" >/dev/null; done
for key in approved other; do
  gpg --homedir "$tmp/keys" --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key "$key <fixture-$key@example.invalid>" ed25519 sign 0 >/dev/null 2>&1
done
fingerprint="$(gpg --homedir "$tmp/keys" --with-colons --fingerprint fixture-approved@example.invalid 2>/dev/null | awk -F: '$1=="fpr"{print $10; exit}')"
gpg --homedir "$tmp/keys" --batch --export > "$tmp/fedora.gpg"
iso_name=Fedora-Workstation-Live-44-1.7.x86_64.iso
checksum_name=Fedora-Workstation-44-1.7-x86_64-CHECKSUM
printf 'disposable ISO fixture\n' > "$tmp/$iso_name"
digest="$(sha256sum "$tmp/$iso_name" | awk '{print $1}')"
cat > "$tmp/installer/fedora44-media.lock" <<LOCK
FEDORA_RELEASE=44
FEDORA_COMPOSE=1.7
ISO_FILENAME=$iso_name
ISO_SHA256=$digest
CHECKSUM_FILENAME=$checksum_name
SIGNING_FINGERPRINT=$fingerprint
LOCK
sign() {
  gpg --homedir "$tmp/keys" --batch --yes --pinentry-mode loopback --passphrase '' \
    --local-user "fixture-${1:-approved}@example.invalid" --clearsign \
    --output "$tmp/$checksum_name" "$tmp/plain" >/dev/null 2>&1
}
verify() {
  bash "$tmp/installer/verify-fedora44-media.sh" --iso "$tmp/$iso_name" \
    --checksum "$tmp/$checksum_name" --keyring "$tmp/fedora.gpg"
}
printf 'SHA256 (%s) = %s\n' "$iso_name" "$digest" > "$tmp/plain"
sign; verify
sign other
if verify >/dev/null 2>&1; then echo 'wrong signing identity accepted' >&2; exit 1; fi
printf 'SHA256 (%s) = %064d\nSHA256 (different.iso) = %s\n' "$iso_name" 0 "$digest" > "$tmp/plain"
sign
if verify >/dev/null 2>&1; then echo 'unpaired filename and hash accepted' >&2; exit 1; fi
printf 'SHA256 (%s) = %s\n' "$iso_name" "$digest" > "$tmp/plain"
cp "$tmp/plain" "$tmp/$checksum_name"
if verify >/dev/null 2>&1; then echo 'unsigned checksum accepted' >&2; exit 1; fi
sign
printf 'modified bytes' >> "$tmp/$iso_name"
if verify >/dev/null 2>&1; then echo 'modified ISO accepted' >&2; exit 1; fi
echo 'Fedora media signature behavior: PASS'

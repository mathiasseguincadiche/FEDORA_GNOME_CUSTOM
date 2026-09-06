#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$REPO_ROOT/installer/fedora44-media.lock"
usage(){ echo "Usage: $0 --iso FILE --checksum FILE --keyring FEDORA_GPG_KEYRING" >&2; }
iso=''; checksum=''; keyring=''
while (($#)); do case "$1" in --iso) iso="${2:-}"; shift 2;; --checksum) checksum="${2:-}"; shift 2;; --keyring) keyring="${2:-}"; shift 2;; *) usage; exit 2;; esac; done
[[ -r "$iso" && -r "$checksum" && -r "$keyring" ]] || { usage; exit 2; }
[[ "$(basename "$iso")" == "$ISO_FILENAME" ]] || { echo "Unexpected ISO filename: $(basename "$iso")" >&2; exit 1; }
[[ "$(basename "$checksum")" == "$CHECKSUM_FILENAME" ]] || { echo "Unexpected CHECKSUM filename: $(basename "$checksum")" >&2; exit 1; }
command -v gpgv >/dev/null || { echo 'gpgv is required' >&2; exit 1; }
actual="$(sha256sum "$iso" | awk '{print $1}')"; [[ "$actual" == "$ISO_SHA256" ]] || { echo "ISO SHA256 mismatch: $actual" >&2; exit 1; }
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
gpgv --keyring "$keyring" --output "$tmp" "$checksum"
grep -Fq "$ISO_SHA256" "$tmp" || { echo 'Signed CHECKSUM does not contain the locked ISO SHA256' >&2; exit 1; }
grep -Fq "$ISO_FILENAME" "$tmp" || { echo 'Signed CHECKSUM does not name the locked ISO' >&2; exit 1; }
printf 'Fedora 44 media PASS: %s\ncompose=%s sha256=%s\n' "$ISO_FILENAME" "$FEDORA_COMPOSE" "$ISO_SHA256"

#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
release=44
if [[ "${1:-}" == --release ]]; then release="${2:-}"; shift 2; fi
case "$release" in
  44) ;;
  45) python3 "$REPO_ROOT/scripts/development/fedora-profile.py" validate "$REPO_ROOT" 45 ;;
  *) echo 'Unsupported Fedora release' >&2; exit 2 ;;
esac
source "$REPO_ROOT/installer/fedora$release-media.lock"
usage(){ echo "Usage: $0 --iso FILE --checksum FILE --keyring FEDORA_GPG_KEYRING" >&2; }
iso=''; checksum=''; keyring=''
while (($#)); do case "$1" in --iso) iso="${2:-}"; shift 2;; --checksum) checksum="${2:-}"; shift 2;; --keyring) keyring="${2:-}"; shift 2;; *) usage; exit 2;; esac; done
[[ -r "$iso" && -r "$checksum" && -r "$keyring" ]] || { usage; exit 2; }
[[ "$(basename "$iso")" == "$ISO_FILENAME" ]] || { echo "Unexpected ISO filename: $(basename "$iso")" >&2; exit 1; }
[[ "$(basename "$checksum")" == "$CHECKSUM_FILENAME" ]] || { echo "Unexpected CHECKSUM filename: $(basename "$checksum")" >&2; exit 1; }
command -v gpgv >/dev/null || { echo 'gpgv is required' >&2; exit 1; }
actual="$(sha256sum "$iso" | awk '{print $1}')"; [[ "$actual" == "$ISO_SHA256" ]] || { echo "ISO SHA256 mismatch: $actual" >&2; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
gpgv --status-fd 3 --keyring "$keyring" --output "$tmp/checksum" "$checksum" 3> "$tmp/signature"
python3 - "$tmp/signature" "$tmp/checksum" "$SIGNING_FINGERPRINT" "$ISO_FILENAME" "$ISO_SHA256" <<'PY'
import pathlib, re, sys
status, checksums, fingerprint, filename, digest = sys.argv[1:]
valid=[line.split() for line in pathlib.Path(status).read_text().splitlines() if line.startswith("[GNUPG:] VALIDSIG ")]
# A signing subkey is accepted only if its primary key has the pinned identity.
if not valid or not any(row[2]==fingerprint or row[-1]==fingerprint for row in valid):
    raise SystemExit("Unexpected Fedora signing key")
pattern=r"SHA256 \(" + re.escape(filename) + r"\) = " + re.escape(digest)
rows=pathlib.Path(checksums).read_text().splitlines()
if sum(bool(re.fullmatch(pattern,row)) for row in rows)!=1:
    raise SystemExit("Signed CHECKSUM must bind the exact filename to the exact hash")
PY
printf 'Fedora %s media PASS: %s\ncompose=%s sha256=%s\n' "$release" "$ISO_FILENAME" "$FEDORA_COMPOSE" "$ISO_SHA256"

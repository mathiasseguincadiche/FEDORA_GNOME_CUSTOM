#!/usr/bin/env bash
set -Eeuo pipefail

# https://rockylinux.org/resources/gpg-key-info — production Rocky Linux 10 key.
ROCKY_CLOUD_IMAGE_FINGERPRINT="FC226859C0860BF0DDB95B085B106C736FEDFC85"
usage() {
  cat <<'TXT'
Usage: verify_rocky_cloud_image.sh --image IMAGE --sha256sums CHECKSUM
       --signature CHECKSUM.asc [--key-file RPM-GPG-KEY-Rocky-10]
Accepts only versioned Rocky Linux 10.2 GenericCloud Base x86_64 qcow2 images.
The detached signature must bind the checksum to the pinned production key;
the filename and SHA-256 must occur together on exactly one authenticated row.
TXT
}
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
image="" sums="" signature="" key_file=""
while (($#)); do
  case "$1" in
    --image|--sha256sums|--signature|--key-file)
      (($# >= 2)) || fail "missing value for $1"
      case "$1" in
        --image) image="$2" ;; --sha256sums) sums="$2" ;;
        --signature) signature="$2" ;; --key-file) key_file="$2" ;;
      esac
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done
for cmd in gpg gpgv sha256sum python3; do command -v "$cmd" >/dev/null || fail "missing command: $cmd"; done
[[ -f "$image" && -r "$image" && ! -L "$image" ]] || fail 'readable regular image required'
[[ -f "$sums" && -r "$sums" && -f "$signature" && -r "$signature" ]] || fail 'CHECKSUM and detached CHECKSUM.asc required'
image_name="$(basename "$image")"
[[ "$image_name" =~ ^Rocky-10-GenericCloud-Base-10[.]2-[0-9]{8}[.][0-9]+[.]x86_64[.]qcow2$ ]] || fail 'expected versioned Rocky Linux 10.2 GenericCloud Base x86_64 image'
tmpdir="$(mktemp -d)"
chmod 0700 "$tmpdir"
trap 'rm -rf "$tmpdir"' EXIT
if [[ -z "$key_file" ]]; then
  command -v curl >/dev/null || fail 'curl required to retrieve Rocky key; use --key-file offline'
  key_file="$tmpdir/RPM-GPG-KEY-Rocky-10"
  curl --proto '=https' --tlsv1.2 -fsSL --retry 3 https://dl.rockylinux.org/pub/rocky/RPM-GPG-KEY-Rocky-10 -o "$key_file"
fi
[[ -f "$key_file" && -r "$key_file" ]] || fail 'Rocky key file not readable'
actual_fingerprint="$(gpg --batch --show-keys --with-colons "$key_file" 2>/dev/null | awk -F: '$1=="fpr" {print toupper($10); exit}')"
[[ "$actual_fingerprint" == "$ROCKY_CLOUD_IMAGE_FINGERPRINT" ]] || fail "unexpected Rocky key fingerprint: $actual_fingerprint"
gpg --homedir "$tmpdir" --batch --quiet --import "$key_file" >/dev/null 2>&1
# Export only the pinned key: a supplied bundle must not authorize other keys.
gpg --homedir "$tmpdir" --batch --export "$ROCKY_CLOUD_IMAGE_FINGERPRINT" >"$tmpdir/trusted.gpg"
gpgv --homedir "$tmpdir" --keyring "$tmpdir/trusted.gpg" --status-fd 1 "$signature" "$sums" >"$tmpdir/status" 2>"$tmpdir/signature.log" || fail 'CHECKSUM signature verification failed'
awk -v pin="$ROCKY_CLOUD_IMAGE_FINGERPRINT" '
  $1=="[GNUPG:]" && $2=="VALIDSIG" && ($3==pin || $NF==pin) {valid++}
  END {exit valid!=1}
' "$tmpdir/status" || fail 'signature is not bound to the pinned Rocky production key'
expected="$(python3 - "$sums" "$image_name" <<'PY'
import re, sys
from pathlib import Path
name=sys.argv[2]
matches=[]
for line in Path(sys.argv[1]).read_text(encoding="utf-8").splitlines():
    bsd=re.fullmatch(r"SHA256 \(([^)]+)\) = ([0-9A-Fa-f]{64})", line.strip())
    gnu=re.fullmatch(r"([0-9A-Fa-f]{64})[ \t]+[*]?([^ \t]+)", line.strip())
    if bsd and bsd[1]==name: matches.append(bsd[2])
    if gnu and gnu[2]==name: matches.append(gnu[1])
if len(matches)!=1: raise SystemExit("selected filename must have exactly one authenticated SHA-256 row")
print(matches[0].lower())
PY
)"
actual="$(sha256sum "$image" | awk '{print $1}')"
[[ "$actual" == "$expected" ]] || fail "image SHA-256 mismatch: expected=$expected actual=$actual"
printf 'Rocky cloud image verification: PASS\nimage=%s\nsha256=%s\nsigner_fingerprint=%s\n' "$image_name" "$actual" "$ROCKY_CLOUD_IMAGE_FINGERPRINT"

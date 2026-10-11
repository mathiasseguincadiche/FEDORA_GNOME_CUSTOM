#!/usr/bin/env bash
# Real signatures in a disposable Git checkout: the Fedora 45 promotion accepts only a final,
# correctly named ISO bound by a CHECKSUM signed with the pinned key, leaves the profile
# untouched on any refusal, and produces a profile the real validator accepts.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for cmd in gpg gpgv git python3 sha256sum; do command -v "$cmd" >/dev/null; done
mkdir -m 700 "$tmp/keys"
for key in approved other; do
  gpg --homedir "$tmp/keys" --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key "$key <fixture-$key@example.invalid>" ed25519 sign 0 >/dev/null 2>&1
done
fingerprint="$(gpg --homedir "$tmp/keys" --with-colons --fingerprint fixture-approved@example.invalid 2>/dev/null | awk -F: '$1=="fpr"{print $10; exit}')"
gpg --homedir "$tmp/keys" --batch --export > "$tmp/fedora.gpg"

repo="$tmp/repo"
mkdir -p "$repo/scripts/development" "$repo/profiles/fedora45" "$repo/installer" "$repo/config"
cp "$ROOT/scripts/development/promote-fedora45.py" "$ROOT/scripts/development/fedora-profile.py" "$repo/scripts/development/"
cp "$ROOT/profiles/fedora45/gnome-extensions.lock" "$ROOT/profiles/fedora45/packages-nautilus.txt" "$repo/profiles/fedora45/"
cp "$ROOT/installer/fedora44-media.lock" "$repo/installer/"
cp "$ROOT/config/gnome-extensions.lock" "$repo/config/"
real='4F50A6114CD5C6976A7F1179655A4B02F577861E'
sed "s/$real/$fingerprint/" "$ROOT/profiles/fedora45/profile.json" > "$repo/profiles/fedora45/profile.json"
sed -i "s/$real/$fingerprint/g" "$repo/scripts/development/fedora-profile.py"
git -C "$repo" init -q
git -C "$repo" -c user.name=t -c user.email=t@example.invalid add -A
git -C "$repo" -c user.name=t -c user.email=t@example.invalid commit -q -m fixture
head="$(git -C "$repo" rev-parse HEAD)"
pending="$(cat "$repo/profiles/fedora45/profile.json")"

iso=Fedora-Workstation-Live-45-1.3.x86_64.iso
checksum=Fedora-Workstation-45-1.3-x86_64-CHECKSUM
printf 'disposable ISO fixture\n' > "$tmp/$iso"
digest="$(sha256sum "$tmp/$iso" | awk '{print $1}')"
sign() {
  printf 'SHA256 (%s) = %s\n' "$iso" "${2:-$digest}" > "$tmp/plain"
  gpg --homedir "$tmp/keys" --batch --yes --pinentry-mode loopback --passphrase '' \
    --local-user "fixture-${1:-approved}@example.invalid" --clearsign --output "$tmp/$checksum" "$tmp/plain" >/dev/null 2>&1
}
promote() {
  python3 -I "$repo/scripts/development/promote-fedora45.py" --root "$repo" --iso "$tmp/${ISO:-$iso}" \
    --checksum "$tmp/${CHECKSUM:-$checksum}" --keyring "$tmp/fedora.gpg" --commit "${COMMIT:-$head}"
}
refused() { # refused CASE REASON: promotion must fail for that reason and leave the profile as it was
  local output
  if output="$(promote 2>&1)"; then echo "accepted: $1" >&2; exit 1; fi
  grep -Fq "$2" <<<"$output" || { echo "refused $1 for the wrong reason: $output" >&2; exit 1; }
  [[ "$(cat "$repo/profiles/fedora45/profile.json")" == "$pending" ]] || { echo "profile changed after refusal: $1" >&2; exit 1; }
  [[ ! -e "$repo/installer/fedora45-media.lock" ]] || { echo "media lock left behind after refusal: $1" >&2; exit 1; }
}

sign other; refused 'wrong signing identity' 'not signed by the pinned'
sign approved "$(printf '%064d' 0)"; refused 'checksum bound to another hash' 'exact ISO hash'
sign approved
(ISO=Fedora-Workstation-Live-45_Beta-1.2.x86_64.iso; cp "$tmp/$iso" "$tmp/$ISO"; export ISO; refused 'Beta image name' 'Beta/RC names are refused')
(COMMIT="$(printf 'a%.0s' {1..40})"; export COMMIT; refused 'commit that is not HEAD' 'must be the current HEAD')
echo dirty > "$repo/untracked"; refused 'dirty tree' 'not clean'; rm "$repo/untracked"
cp "$tmp/$iso" "$tmp/iso.bak"; printf 'x' >> "$tmp/$iso"; refused 'modified ISO bytes' 'exact ISO hash'; mv "$tmp/iso.bak" "$tmp/$iso"

promote >/dev/null
python3 - "$repo" "$digest" "$head" <<'PY'
import json, pathlib, sys
root, digest, head = pathlib.Path(sys.argv[1]), sys.argv[2], sys.argv[3]
profile = json.loads((root / "profiles/fedora45/profile.json").read_text())
assert profile["status"] == "ready" and profile["promotion_source_commit"] == head
lock = (root / "installer/fedora45-media.lock").read_text()
assert "ISO_SHA256=" + digest in lock and "RELEASE_STATUS=final" in lock and "FEDORA_COMPOSE=1.3" in lock
PY
echo 'Fedora 45 promotion behavior: PASS'

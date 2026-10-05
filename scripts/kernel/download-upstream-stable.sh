#!/usr/bin/env bash
# Retrieve official signed source without installing or changing the boot chain.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
[[ "${1:-}" == --output && "${2:-}" == /* && "$#" == 2 ]] || {
  echo "Usage: $0 --output /absolute/empty/directory" >&2; exit 2;
}
target="$2"
[[ ! -e "$target" ]] || { echo 'Refusing an existing source directory.' >&2; exit 2; }
for cmd in python3 curl gpg gpgv xz sha256sum; do command -v "$cmd" >/dev/null; done
version="$(python3 "$ROOT/scripts/kernel/upstream-release.py")"
major="${version%%.*}"
mkdir -m 700 "$target" "$target/gnupg"
# Published fingerprints: https://www.kernel.org/signature.html
greg=647F28654894E3BD457199BE38DBBDC86092693E
linus=ABAF11C65A2970B130ABE3C479BE3E4300411886
base="https://cdn.kernel.org/pub/linux/kernel/v$major.x"
for suffix in tar.xz tar.sign; do
  curl --fail --location --proto '=https' --proto-redir '=https' --tlsv1.2 --retry 3 \
    "$base/linux-$version.$suffix" --output "$target/linux-$version.$suffix"
done
gpg --homedir "$target/gnupg" --batch --auto-key-locate clear,wkd --locate-keys gregkh@kernel.org torvalds@kernel.org
gpg --homedir "$target/gnupg" --batch --export "$greg" "$linus" > "$target/release-keys.gpg"
[[ -s "$target/release-keys.gpg" ]]
xz --decompress --stdout "$target/linux-$version.tar.xz" \
  | gpgv --status-fd 2 --keyring "$target/release-keys.gpg" \
      "$target/linux-$version.tar.sign" - 2> "$target/signature.log"
python3 - "$target/signature.log" "$greg" "$linus" <<'PY'
import pathlib,sys
allowed=set(sys.argv[2:])
rows=[line.split() for line in pathlib.Path(sys.argv[1]).read_text().splitlines() if line.startswith("[GNUPG:] VALIDSIG ")]
if not any(row[2] in allowed or row[-1] in allowed for row in rows):
    raise SystemExit("Unexpected upstream signing key")
PY
(cd "$target" && sha256sum "linux-$version.tar.xz" > SHA256SUMS)
printf 'upstream_version=%s\nsource_signature=PASS\n' "$version" > "$target/source.env"
echo "Official Linux $version source verified in $target; no kernel was installed."

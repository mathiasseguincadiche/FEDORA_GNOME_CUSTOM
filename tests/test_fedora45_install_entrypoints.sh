#!/usr/bin/env bash
# Dispatchers are tested with disposable engines; real pending guards touch no disks.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/installer/lib"
for script in generate-fedora-kickstart.sh generate-fedora45-kickstart.sh verify-fedora-media.sh; do
  cp "$ROOT/installer/$script" "$tmp/installer/"
done
for engine in generate-kickstart.sh verify-media.sh; do
  cat > "$tmp/installer/lib/$engine" <<'STUB'
#!/usr/bin/env bash
printf '<%s>\n' "$@"
STUB
done
fail() { printf 'Fedora 45 install entrypoints: FAIL: %s\n' "$*" >&2; exit 1; }
expected=$'<--release>\n<45>\n<--disk>\n<DISPOSABLE>'
for script in generate-fedora-kickstart.sh generate-fedora45-kickstart.sh; do
  for explicit in false true; do
    args=(); [[ "$explicit" == false ]] || args=(--release 45)
    actual="$(bash "$tmp/installer/$script" "${args[@]}" --disk DISPOSABLE)"
    [[ "$actual" == "$expected" ]] || fail "$script lost the Fedora 45 selection or arguments"
  done
done
expected=$'<--release>\n<45>\n<--iso>\n<DISPOSABLE>'
actual="$(bash "$tmp/installer/verify-fedora-media.sh" --iso DISPOSABLE)"
[[ "$actual" == "$expected" ]] || fail 'generic verifier did not select Fedora 45'
for script in generate-fedora-kickstart.sh generate-fedora45-kickstart.sh verify-fedora-media.sh; do
  for release in 44 46 ''; do
    if bash "$tmp/installer/$script" --release "$release" >/dev/null 2>&1; then
      fail "$script accepted unsupported/missing release $release"
    fi
  done
done
if grep -Eq '"status"[[:space:]]*:[[:space:]]*"pending"' "$ROOT/profiles/fedora45/profile.json"; then
  for script in generate-fedora-kickstart.sh generate-fedora45-kickstart.sh verify-fedora-media.sh; do
    output="$(cd "$tmp" && bash "$ROOT/installer/$script" --disk /dev/disk/by-id/nvme-NONEXISTENT 2>&1)" && fail "$script accepted pending profile"
    grep -qi 'pending' <<<"$output" || fail "$script failed for a different reason: $output"
  done
  [[ ! -e "$tmp/fedora45-golden-workstation.ks" ]] || fail 'Kickstart written while pending'
fi
printf 'Fedora 45 fresh-install entrypoints: PASS\n'

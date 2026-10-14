#!/usr/bin/env bash
# No real disks or media: test dispatcher selection through disposable stubs.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/installer"
cp "$ROOT/installer/generate-fedora-kickstart.sh" "$tmp/installer/"
cp "$ROOT/installer/generate-fedora45-kickstart.sh" "$tmp/installer/"
cp "$ROOT/installer/verify-fedora-media.sh" "$tmp/installer/"
for legacy in generate-fedora44-kickstart.sh verify-fedora44-media.sh; do
  cat > "$tmp/installer/$legacy" <<'STUB'
#!/usr/bin/env bash
printf '<%s>\n' "$@"
STUB
done
fail() { printf 'Fedora 45 install entrypoints: FAIL: %s\n' "$*" >&2; exit 1; }
expected=$'<--release>\n<45>\n<--disk>\n<DISPOSABLE>'
actual="$(bash "$tmp/installer/generate-fedora-kickstart.sh" --disk DISPOSABLE)"
[[ "$actual" == "$expected" ]] || fail 'generic Kickstart did not select Fedora 45'
actual="$(bash "$tmp/installer/generate-fedora-kickstart.sh" --release 45 --disk DISPOSABLE)"
[[ "$actual" == "$expected" ]] || fail 'explicit Fedora 45 invocation lost arguments'
actual="$(bash "$tmp/installer/generate-fedora45-kickstart.sh" --disk DISPOSABLE)"
[[ "$actual" == "$expected" ]] || fail 'Fedora 45-specific generator lost release selection'
expected=$'<--release>\n<45>\n<--iso>\n<DISPOSABLE>'
actual="$(bash "$tmp/installer/verify-fedora-media.sh" --iso DISPOSABLE)"
[[ "$actual" == "$expected" ]] || fail 'generic media verifier did not select Fedora 45'
actual="$(bash "$tmp/installer/verify-fedora-media.sh" --release 45 --iso DISPOSABLE)"
[[ "$actual" == "$expected" ]] || fail 'explicit Fedora 45 media verification lost arguments'
for script in generate-fedora-kickstart.sh generate-fedora45-kickstart.sh verify-fedora-media.sh; do
  if bash "$tmp/installer/$script" --release 44 >/dev/null 2>&1; then
    fail "$script fell back to Fedora 44"
  fi
  if bash "$tmp/installer/$script" --release >/dev/null 2>&1; then
    fail "$script accepted a missing release argument"
  fi
done
# While the target is pending, the REAL validator must reject both entrypoints
# before any disk inspection, password prompt, checksum read or output file.
if grep -Eq '"status"[[:space:]]*:[[:space:]]*"pending"' "$ROOT/profiles/fedora45/profile.json"; then
  for script in generate-fedora-kickstart.sh generate-fedora45-kickstart.sh verify-fedora-media.sh; do
    output="$(cd "$tmp" && bash "$ROOT/installer/$script" --disk /dev/disk/by-id/nvme-NONEXISTENT 2>&1)" && fail "$script accepted pending profile"
    grep -qi 'pending' <<<"$output" || fail "$script failed for a reason other than pending profile: $output"
  done
  [[ ! -e "$tmp/fedora45-golden-workstation.ks" ]] || fail 'Kickstart written while pending'
fi
printf 'Fedora 45 fresh-install entrypoints: PASS\n'

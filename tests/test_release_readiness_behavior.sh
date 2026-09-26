#!/usr/bin/env bash
# Behavioral test: runs the Fedora N+1 readiness tool against a fake curl that
# serves extensions.gnome.org, COPR and GitHub answers, including a component
# that is not ready yet. The tool must never install or change anything.
# shellcheck disable=SC2016
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "release readiness behavior: FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin"

# Fake extension zip declaring GNOME Shell 50 and 51.
python3 - "$tmp/ta.zip" <<'PY'
import json, sys, zipfile
with zipfile.ZipFile(sys.argv[1], 'w') as z:
    z.writestr('metadata.json', json.dumps({"uuid": "tiling-assistant@leleat-on-github", "shell-version": ["50", "51"]}))
PY

cat > "$tmp/bin/curl" <<SH
#!/usr/bin/env bash
out=''; url=''
while ((\$#)); do case "\$1" in --output) out="\$2"; shift 2 ;; -*) shift ;; *) url="\$1"; shift ;; esac; done
respond() { if [[ -n "\$out" ]]; then printf '%s' "\$1" > "\$out"; else printf '%s' "\$1"; fi; }
case "\$url" in
  *extension-info/*uuid=ding@rastersoft.com*) respond '{"version": 97, "version_tag": 80001}' ;;
  *extension-info/*uuid=show-desktop-plus*) respond '{"version": 9, "version_tag": 80002}' ;;
  *extension-info/*uuid=Resource_Monitor*) exit 22 ;;   # not ported yet
  *review/download/*) respond 'zipbytes' ;;
  *projectname=kernel-cachyos*) respond '{"chroot_repos": {"fedora-44-x86_64": "x", "fedora-45-x86_64": "y"}}' ;;
  *projectname=stable*) respond '{"chroot_repos": {"fedora-44-x86_64": "x"}}' ;;
  *releases/latest) respond '{"tag_name": "v56", "assets": [{"name": "tiling-assistant@leleat-on-github.shell-extension.zip", "browser_download_url": "https://example.invalid/ta.zip"}]}' ;;
  https://example.invalid/ta.zip) cp "$tmp/ta.zip" "\$out" ;;
  *) exit 22 ;;
esac
SH
chmod +x "$tmp/bin/curl"

rc=0
out="$(PATH="$tmp/bin:$PATH" bash "$ROOT/scripts/development/release-readiness.sh" --pin 2>&1)" || rc=$?
[[ "$rc" -eq 1 ]] || fail "blocked components must give exit 1 (rc=$rc)"
grep -Eq 'READY +kernel-cachyos COPR' <<<"$out" || fail 'cachyos COPR readiness'
grep -Eq 'BLOCKED +kernel-vanilla COPR' <<<"$out" || fail 'missing vanilla chroot not reported'
grep -Eq 'READY +Desktop Icons NG +site version 97, review 80001' <<<"$out" || fail 'DING candidate'
grep -Fq 'DING_SOURCE_URL="https://extensions.gnome.org/review/download/80001.shell-extension.zip"' <<<"$out" || fail 'DING pin line'
grep -Fq 'DING_SHA256="' <<<"$out" || fail 'DING SHA-256 line'
grep -Eq 'BLOCKED +Resource Monitor' <<<"$out" || fail 'unported extension not blocked'
grep -Eq 'READY +Tiling Assistant +v56 declares GNOME Shell 51' <<<"$out" || fail 'Tiling Assistant metadata inspection'

rc=0
PATH="$tmp/bin:$PATH" bash "$ROOT/scripts/development/release-readiness.sh" --report-only >/dev/null 2>&1 || rc=$?
[[ "$rc" -eq 0 ]] || fail '--report-only must never fail the CI report'
# Everything ready (and dnf5 absent, as on the CI runner): exit 0, no abort.
sed -i -e 's|\*extension-info/\*uuid=Resource_Monitor\*) exit 22 ;;|*extension-info/*uuid=Resource_Monitor*) respond "{\\"version\\": 29, \\"version_tag\\": 80003}" ;;|' \
       -e 's|"fedora-44-x86_64": "x"}}|"fedora-44-x86_64": "x", "fedora-45-x86_64": "z"}}|' "$tmp/bin/curl"
out="$(PATH="$tmp/bin:$PATH" bash "$ROOT/scripts/development/release-readiness.sh" 2>&1)" || fail "all-ready run failed: $out"
grep -Fq 'READY=6 BLOCKED=0' <<<"$out" || fail "all-ready summary: $(tail -3 <<<"$out")"
echo 'release readiness behavior: PASS'

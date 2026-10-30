#!/usr/bin/env bash
# RPM version queries with a fake rpm that behaves like the real one: for a
# package that is not installed, `rpm -q --qf` prints "package X is not
# installed" on stdout and exits 1. That text must never be taken as a version:
# the software matrix refuses a missing required package, and fingerprints say
# "missing".
# shellcheck disable=SC2016,SC1090,SC1091,SC2015
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "rpm query behavior: FAIL: $*" >&2; exit 1; }
fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/home"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home"
printf '#!/usr/bin/env bash\n[[ "$1" == -q ]] && shift; [[ "$1" == --qf ]] && shift 2\nfor pkg; do [[ " ${T_MISSING:-} " != *" $pkg "* ]] || { echo "package $pkg is not installed"; exit 1; }; done\necho 1.0-1.fc45\n' > "$tmp/bin/rpm"
chmod +x "$tmp/bin/rpm"
export PATH="$tmp/bin:$PATH"

source "$ROOT/lib/common.sh"
[[ "$(rpm_installed_query '%{VERSION}' mutter)" == 1.0-1.fc45 ]] || fail 'installed package version not returned'
if out="$(T_MISSING=mutter rpm_installed_query '%{VERSION}' mutter)"; then fail "missing package returned a version: $out"; fi
[[ -z "$(T_MISSING=mutter rpm_installed_query '%{VERSION}' mutter || true)" ]] || fail 'missing package printed something'
source "$ROOT/lib/baseline.sh"
[[ "$(T_MISSING=mesa-vulkan-drivers runtime_component_version mesa-vulkan-drivers)" == missing ]] || fail 'runtime fingerprint shows the rpm message as a version'

# The software matrix refuses a missing required package instead of recording its message.
matrix() { env "$@" bash "$fixture/diagnostics/software-matrix-doctor" snapshot > "$tmp/out" 2>&1; }
matrix || { cat "$tmp/out" >&2; fail 'complete software matrix refused'; }
grep -Fxq 'mutter=1.0-1.fc45' "$tmp/out" || fail 'software matrix lacks an installed version'
rc=0; matrix T_MISSING=mutter || rc=$?
[[ "$rc" != 0 ]] || fail 'software matrix accepted a missing required package'
grep -Fq 'is not installed' "$fixture/state/software-matrix/current.env" 2>/dev/null && fail 'rpm message recorded as a version'

echo 'rpm query behavior: PASS'

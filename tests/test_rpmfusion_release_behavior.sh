#!/usr/bin/env bash
# Exercise scripts/packages/install-rpmfusion-release.sh with fake dnf, rpm, curl, gpg and
# rpmkeys: the rpm fallback runs only for the known dnf5 case and refuses everything else.
# shellcheck disable=SC2016  # fake binaries are written verbatim, expanded at call time
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
helper="$ROOT/scripts/packages/install-rpmfusion-release.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/dnfconf" "$tmp/keys"
fail() { echo "rpmfusion release behavior: FAIL: $*" >&2; exit 1; }
fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
cp "$ROOT/config/keys/RPM-GPG-KEY-rpmfusion-free-fedora-2020" "$tmp/keys/"

# Fakes record every call in $T_LOG; T_* variables shape each case.
fake dnf 'echo "dnf $*" >> "$T_LOG"; [[ "${T_DNF_RC:-1}" == 0 ]] && touch "$T_STATE"; exit "${T_DNF_RC:-1}"'
fake curl 'echo "curl $*" >> "$T_LOG"; while [[ $# -gt 0 ]]; do [[ "$1" == -o ]] && { echo rpm > "$2"; shift; }; shift; done; exit "${T_CURL_RC:-0}"'
fake gpg 'printf "pub:-:4096:1:E06F8ECDD651FF2E:::::::scESC::::::23::0:\nfpr:::::::::%s:\n" "${T_KEY_FPR:-E9A491A3DE247814E7E067EAE06F8ECDD651FF2E}"'
fake rpmkeys 'echo "rpmkeys $*" >> "$T_LOG"; [[ "$1" == --checksig ]] && exit "${T_CHECKSIG_RC:-0}"; exit 0'
fake rpm '
case "$*" in
  "-q rpmfusion-free-release") [[ -e "$T_STATE" ]] && { echo rpmfusion-free-release-45-1.noarch; exit 0; }; exit 1 ;;
  "-qp --qf %{NAME} %{VERSION} %{ARCH} "*) echo "${T_IDENTITY:-rpmfusion-free-release 45 noarch}" ;;
  "-qp --requires "*) printf "%s\n" "/usr/share/dnf5/libdnf.conf.d/" "system-release(45)" "rpmlib(PayloadIsZstd) <= 5.4.18-1" ${T_EXTRA_REQUIRE:+"$T_EXTRA_REQUIRE"} ;;
  "-qp --qf %{RSAHEADER:pgpsig} "*) echo "RSA/SHA256, Mon Nov  2 06:36:01 2026, Key ID ${T_SIG_KEY:-e06f8ecdd651ff2e}" ;;
  "-q --whatprovides system-release(45)") [[ -z "${T_NO_SYSTEM_RELEASE:-}" ]] ;;
  "-i --nodeps "*) echo "rpm $*" >> "$T_LOG"; touch "$T_STATE" ;;
  *) echo "unexpected rpm $*" >&2; exit 99 ;;
esac'

URL=https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-45.noarch.rpm
URLS=()
# The fallback requires root; run as root, through sudo -n, or in a user namespace.
if [[ "$EUID" == 0 ]]; then as_root=()
elif sudo -n true 2>/dev/null; then as_root=(sudo -n)
elif unshare --user --map-root-user true 2>/dev/null; then as_root=(unshare --user --map-root-user)
else as_root=(); echo 'rpmfusion release behavior: root cases SKIPPED (no root, sudo -n or user namespace)'; fi

run() {  # run EXPECTED_RC [root] VAR=value...
  local expected="$1"; shift
  local -a prefix=()
  if [[ "${1:-}" == root ]]; then prefix=("${as_root[@]}"); shift; fi
  : > "$tmp/log"; rm -f "$tmp/installed"
  local rc=0
  # The root prefix comes first: sudo resets PATH, env then restores the fakes.
  "${prefix[@]}" env PATH="$tmp/bin:$PATH" T_LOG="$tmp/log" T_STATE="$tmp/installed" RPMFUSION_KEY_DIR="$tmp/keys" \
    RPMFUSION_DNF_CONF_DIR="$tmp/dnfconf" "$@" bash "$helper" 45 free "${URLS[@]:-$URL}" \
    > "$tmp/out" 2>&1 || rc=$?
  [[ "$rc" == "$expected" ]] || fail "expected rc=$expected, got $rc: $(cat "$tmp/out")"
}
refused() {  # refused MESSAGE VAR=value...
  local message="$1"; shift
  run 1 root "$@"
  grep -Fq "$message" "$tmp/out" || fail "missing refusal '$message': $(cat "$tmp/out")"
  if grep -q '^rpm -i' "$tmp/log"; then fail "rpm installed despite: $message"; fi
}

# 1. Normal path: dnf installs the package and the fallback never runs.
run 0 T_DNF_RC=0
grep -Fxq "dnf -y install $URL" "$tmp/log" || fail 'dnf was not tried first'
if grep -q '^curl\|^rpm -i' "$tmp/log"; then fail 'fallback ran although dnf succeeded'; fi

# 2. Arguments are validated before anything runs.
env PATH="$tmp/bin:$PATH" T_LOG="$tmp/log" bash "$helper" 45 tainted "$URL" >/dev/null 2>&1 && fail 'unknown channel accepted'
env PATH="$tmp/bin:$PATH" T_LOG="$tmp/log" bash "$helper" 4x free "$URL" >/dev/null 2>&1 && fail 'invalid release accepted'

if [[ ${#as_root[@]} -gt 0 || "$EUID" == 0 ]]; then
  # 3. The known dnf5 case: verified rpm installation with the pinned key.
  run 0 root
  grep -Fq 'rpm -i --nodeps' "$tmp/log" || fail 'verified fallback did not install'
  grep -Fq "rpmkeys --import $tmp/keys/RPM-GPG-KEY-rpmfusion-free-fedora-2020" "$tmp/log" || fail 'pinned key not imported'
  grep -Fq 'rpmkeys --checksig' "$tmp/log" || fail 'signature not checked'
  grep -Fq 'installing it with rpm after identity, dependency and signature checks' "$tmp/out" || fail 'fallback not announced'

  # 4. Every other situation is refused, and rpm never installs anything.
  refused 'dependencies differ from the known dnf5 case' T_EXTRA_REQUIRE='libfoo.so.1()(64bit)'
  refused 'unexpected package identity' T_IDENTITY='rpmfusion-free-release 44 noarch'
  refused 'unexpected package identity' T_IDENTITY='rpmfusion-nonfree-release 45 noarch'
  refused 'not signed by the pinned key' T_SIG_KEY=0123456789abcdef
  refused 'is not the pinned' T_KEY_FPR=0000000000000000000000000000000000000000
  refused 'signature verification failed' T_CHECKSIG_RC=1
  refused 'system-release(45) is not installed' T_NO_SYSTEM_RELEASE=1
  refused 'download failed' T_CURL_RC=22
  refused 'missing directory' RPMFUSION_DNF_CONF_DIR="$tmp/absent"
  refused 'missing pinned key' RPMFUSION_KEY_DIR="$tmp/nokeys"
  URLS=(http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-45.noarch.rpm)
  refused 'refusing a non-HTTPS URL'
  URLS=()
fi

# 5. Without root, the fallback refuses instead of trying.
if [[ "$EUID" != 0 ]]; then
  run 1
  grep -Fq 'the signed fallback requires root' "$tmp/out" || fail 'non-root fallback not refused'
fi

# 6. An installed package is left alone.
: > "$tmp/log"; touch "$tmp/installed"
env PATH="$tmp/bin:$PATH" T_LOG="$tmp/log" T_STATE="$tmp/installed" bash "$helper" 45 free "$URL" > "$tmp/out"
grep -Fq 'already installed' "$tmp/out" && [[ ! -s "$tmp/log" ]] || fail 'installed package was reinstalled'

echo 'rpmfusion release behavior: PASS'

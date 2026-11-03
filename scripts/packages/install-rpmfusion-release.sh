#!/usr/bin/env bash
# Install one RPM Fusion release package (free or nonfree) from an official URL.
#
# The normal path is `dnf install URL`. dnf5 5.4.6 refuses rpmfusion-*-release-45-1 because
# the package requires the directory "/usr/share/dnf5/libdnf.conf.d/" with a trailing slash,
# which no package provides by that spelling. Only for that exact case, the package is
# installed with rpm after proving: its name and version, that its dependencies are exactly
# that directory and system-release(N), that the directory and system-release(N) are present,
# and that it is signed by the pinned RPM Fusion key shipped in config/keys/. Anything else fails.
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KEY_DIR="${RPMFUSION_KEY_DIR:-$ROOT/config/keys}"
BROKEN_REQUIRE='/usr/share/dnf5/libdnf.conf.d/'
DNF_CONF_DIR="${RPMFUSION_DNF_CONF_DIR:-${BROKEN_REQUIRE%/}}"
declare -A FINGERPRINT=(
  [free]=E9A491A3DE247814E7E067EAE06F8ECDD651FF2E
  [nonfree]=79BDB88F9BBF73910FD4095B6A2AF96194843C65
)

usage() { echo 'Usage: install-rpmfusion-release.sh RELEASE free|nonfree URL...' >&2; exit 2; }
fail() { echo "RPM Fusion $channel: $1" >&2; return 1; }

[[ $# -ge 3 ]] || usage
release="$1" channel="$2"; shift 2
[[ "$release" =~ ^[0-9]+$ && -n "${FINGERPRINT[$channel]:-}" ]] || usage
package="rpmfusion-${channel}-release"
fingerprint="${FINGERPRINT[$channel]}"
key="$KEY_DIR/RPM-GPG-KEY-rpmfusion-${channel}-fedora-2020"

if rpm -q "$package" >/dev/null 2>&1; then
  echo "$package already installed"
  exit 0
fi

verified_rpm_install() {
  local url="$1" work rpm_file requires expected key_fpr signature key_id
  [[ "$url" == https://* ]] || { fail "refusing a non-HTTPS URL: $url"; return 1; }
  [[ "$EUID" == 0 ]] || { fail 'the signed fallback requires root'; return 1; }
  work="$(mktemp -d)"
  rpm_file="$work/$package.rpm"
  # A subshell keeps the cleanup local to this attempt. It runs inside `if`, where errexit
  # is off, so every check stops it explicitly with die.
  (
    trap 'rm -rf -- "$work"' EXIT
    die() { fail "$1"; exit 1; }
    curl -fsSL --proto '=https' --max-time 60 -o "$rpm_file" "$url" || die "download failed: $url"
    [[ "$(rpm -qp --qf '%{NAME} %{VERSION} %{ARCH}' "$rpm_file" 2>/dev/null)" == "$package $release noarch" ]] \
      || die "unexpected package identity from $url"
    requires="$(rpm -qp --requires "$rpm_file" 2>/dev/null | grep -v '^rpmlib(' | sort)"
    expected="$(printf '%s\n' "$BROKEN_REQUIRE" "system-release($release)" | sort)"
    [[ "$requires" == "$expected" ]] || die "dependencies differ from the known dnf5 case; refusing the rpm fallback"
    [[ -d "$DNF_CONF_DIR" ]] || die "missing directory $DNF_CONF_DIR"
    rpm -q --whatprovides "system-release($release)" >/dev/null || die "system-release($release) is not installed"
    [[ -f "$key" && ! -L "$key" ]] || die "missing pinned key $key"
    key_fpr="$(GNUPGHOME="$work" gpg --batch --show-keys --with-colons "$key" 2>/dev/null | awk -F: '$1 == "fpr" { print $10; exit }')"
    [[ "$key_fpr" == "$fingerprint" ]] || die "key file fingerprint ${key_fpr:-none} is not the pinned $fingerprint"
    signature="$(rpm -qp --qf '%{RSAHEADER:pgpsig}' "$rpm_file" 2>/dev/null)"
    key_id="${fingerprint: -16}"
    [[ "${signature,,}" == *"key id ${key_id,,}"* ]] || die "package is not signed by the pinned key ${fingerprint: -16}"
    rpmkeys --import "$key" || die "could not import $key"
    rpmkeys --checksig "$rpm_file" >/dev/null || die 'signature verification failed'
    echo "RPM Fusion $channel: dnf refused the release package; installing it with rpm after identity, dependency and signature checks"
    rpm -i --nodeps "$rpm_file" || die "rpm installation failed"
  )
}

for url in "$@"; do
  if dnf -y install "$url"; then
    rpm -q "$package"
    exit 0
  fi
  if verified_rpm_install "$url"; then
    rpm -q "$package"
    exit 0
  fi
done
fail 'every URL failed'

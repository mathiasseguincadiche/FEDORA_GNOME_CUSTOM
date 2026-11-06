#!/usr/bin/env bash
# CI may report a *proven* upstream packaging delay, but not a test PASS.
# Missing feeds, repository errors and invalid candidates remain hard failures.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
source "$ROOT/lib/constants.sh"
source "$ROOT/lib/kernel_lifecycle.sh"
source "$ROOT/scripts/ci/kernel-rpm-deferred.sh"

export KERNEL_MIN_VERSION=7.2.9
FAKE_UPSTREAM=7.3.3
FAKE_CANDIDATE=7.3.1-400.vanilla.fc45.x86_64
kernel_lifecycle_upstream_latest() {
  [[ -n "$FAKE_UPSTREAM" ]] || return 1
  printf '%s\n' "$FAKE_UPSTREAM"
}
kernel_lifecycle_latest_available() {
  [[ -n "$FAKE_CANDIDATE" ]] || return 1
  printf '%s\n' "$FAKE_CANDIDATE"
}

printf '%s\n' "[KO] kernel.org stable=$FAKE_UPSTREAM; highest RPM candidate=$FAKE_CANDIDATE; exact stable RPM unavailable. Packaging is pending; no other kernel is called latest." > "$tmp/resolution.log"
result="$(kernel_ci_expected_packaging_delay "$EXIT_KERNEL_DEFERRED" "$tmp/resolution.log")"
[[ "$result" == $'upstream=7.3.3\ncandidate=7.3.1-400.vanilla.fc45.x86_64' ]]

if kernel_ci_expected_packaging_delay "$EXIT_SECURITY_BLOCK" "$tmp/resolution.log"; then exit 1; fi
if kernel_ci_expected_packaging_delay "$EXIT_KERNEL_DEFERRED" "$tmp/absent.log"; then exit 1; fi

FAKE_UPSTREAM=''
if kernel_ci_expected_packaging_delay "$EXIT_KERNEL_DEFERRED" "$tmp/resolution.log"; then exit 1; fi
FAKE_UPSTREAM=7.3.3
FAKE_CANDIDATE=''
if kernel_ci_expected_packaging_delay "$EXIT_KERNEL_DEFERRED" "$tmp/resolution.log"; then exit 1; fi

for FAKE_CANDIDATE in \
  7.3.3-400.vanilla.fc45.x86_64 \
  7.3.4-400.vanilla.fc45.x86_64 \
  7.3.1-0.rc1.vanilla.fc45.x86_64 \
  7.2.1-400.vanilla.fc45.x86_64 \
  7.3.1-400.custom.fc45.x86_64; do
  printf '%s\n' "[KO] kernel.org stable=$FAKE_UPSTREAM; highest RPM candidate=$FAKE_CANDIDATE; exact stable RPM unavailable. Packaging is pending; no other kernel is called latest." > "$tmp/resolution.log"
  if kernel_ci_expected_packaging_delay "$EXIT_KERNEL_DEFERRED" "$tmp/resolution.log"; then
    echo "Invalid candidate was accepted as a normal packaging delay: $FAKE_CANDIDATE" >&2
    exit 1
  fi
done

FAKE_CANDIDATE=7.3.1-400.vanilla.fc45.x86_64
printf '%s\n' '[KO] Cannot verify the current kernel.org release feed; refusing a stale target.' > "$tmp/resolution.log"
if kernel_ci_expected_packaging_delay "$EXIT_KERNEL_DEFERRED" "$tmp/resolution.log"; then
  echo 'Unreachable kernel.org feed was treated as a normal packaging delay' >&2
  exit 1
fi

echo 'kernel CI deferred behavior: PASS'

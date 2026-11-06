#!/usr/bin/env bash
# Source only in the disposable CI preflight, after kernel_lifecycle.sh.
# A delayed COPR build is an observed DEFERRED state, not proof of an RPM
# transaction. Runtime installation still requires the exact latest release.

kernel_ci_expected_packaging_delay() {
  local exit_code="$1" report="$2" upstream candidate version earliest
  [[ "$exit_code" == "$EXIT_KERNEL_DEFERRED" && -s "$report" ]] || return 1

  # Recheck both live sources independently: an unreachable feed, missing COPR
  # repository, or malformed candidate must NEVER be called a normal delay.
  upstream="$(kernel_lifecycle_upstream_latest)" || return 1
  candidate="$(kernel_lifecycle_latest_available)" || return 1
  [[ -n "$upstream" && -n "$candidate" ]] || return 1
  grep -Fq "kernel.org stable=$upstream; highest RPM candidate=$candidate; exact stable RPM unavailable" "$report" || return 1
  kernel_lifecycle_release_is_stable "$candidate" || return 1
  kernel_channel_release_matches "$candidate" || return 1
  kernel_lifecycle_version_at_least "$candidate" || return 1
  kernel_lifecycle_version_matches_upstream "$candidate" "$upstream" && return 1

  version="${candidate%%-*}"
  earliest="$(printf '%s\n%s\n' "$version" "$upstream" | sort -V | head -n1)"
  [[ "$earliest" == "$version" ]] || return 1

  printf 'upstream=%s\ncandidate=%s\n' "$upstream" "$candidate"
}

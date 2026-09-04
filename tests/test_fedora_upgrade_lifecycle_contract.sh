#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
engine="$ROOT/scripts/upgrade/upgrade-lifecycle.sh"
policy="$ROOT/config/fedora-upgrade.policy"
workflow="$ROOT/.github/workflows/fedora45-qualification.yml"
helper="$ROOT/lib/fedora-upgrade-qualification.sh"

[[ -x "$engine" ]]
[[ -r "$policy" ]]
[[ -r "$helper" ]]

grep -Fxq 'FEDORA_UPGRADE_SOURCE_RELEASE=44' "$policy"
grep -Fxq 'FEDORA_UPGRADE_TARGET_RELEASE=45' "$policy"
grep -Fxq 'FEDORA_UPGRADE_MAX_HOPS=1' "$policy"
grep -Fxq 'FEDORA_UPGRADE_REQUIRE_FINAL_RELEASE=true' "$policy"
grep -Fxq 'FEDORA_UPGRADE_ALLOW_ALLERASING=false' "$policy"
grep -Fxq 'FEDORA_UPGRADE_AUTOMATIC_REBOOT=false' "$policy"

grep -Fq "upgrade-lifecycle.sh\" \"\${@:2}\"" "$ROOT/control.sh"
grep -Fq 'fedora_upgrade_repoclosure_probe "$target"' "$engine"
grep -Fq "distro-sync --store=\"\$txdir/transaction\"" "$engine"
grep -Fq 'apply_gate_require_backup' "$engine"
grep -Fq 'current_gold_cert_valid' "$engine"
grep -Fq 'qualification_fresh' "$engine"
grep -Fq 'final_release_available' "$engine"
grep -Fq "system-upgrade download --releasever=\"\$target\"" "$engine"
grep -Fq 'There is deliberately no automatic reboot/upgrade command' "$engine"
grep -Fq 'sudo dnf5 system-upgrade reboot' "$engine"
grep -Fq 'Old Golden certificate unexpectedly remains valid' "$engine"
grep -Fq 'mechanism_status=PASS' "$engine"
grep -Fq 'readiness=BLOCKED' "$engine"
grep -Fq 'verdict=BLOCKED' "$engine"

# A Fedora major release is itself part of the runtime fingerprint, so old
# Golden evidence cannot survive a 44 -> 45 transition by accident.
grep -Fq "printf 'fedora_release=%s\\n'" "$ROOT/lib/baseline.sh"

# Current GNOME 50 reviewed artifacts are a business blocker, not a mechanism
# crash. The qualify command records BLOCKED and returns normally.
grep -Fq 'Current reviewed GNOME extension artifacts are pinned to GNOME Shell 50.' "$engine"
! grep -Fq "return \"\$EXIT_PRECHECK_FAILED\"" < <(grep -A8 'GNOME Shell 50' "$engine")

[[ -r "$workflow" ]]
grep -Fq 'container: fedora:45' "$workflow"
grep -Fq 'Fedora 45 / GNOME 51 readiness' "$workflow"
grep -Fq 'fedora45-qualification-report.txt' "$workflow"
grep -Fq 'mechanism_status=PASS' "$workflow"
grep -Fq 'readiness=BLOCKED' "$workflow"
grep -Fq 'Validate Fedora 45 qualification result' "$workflow"
grep -Fq 'fedora_upgrade_repoclosure_probe 45' "$workflow"
grep -Fq 'test -s "$report"' "$workflow"

# Guard rails: no broad error suppression and no forbidden major-upgrade
# dependency erasure. repoclosure remains mandatory.
! grep -Fq 'continue-on-error:' "$workflow"
! grep -Eq 'dnf5 .*--allowerasing' "$engine" "$workflow"
! grep -Eq 'repoclosure .*([|][|] true|continue-on-error)' "$engine" "$workflow"
grep -Fq 'dnf5 --releasever="$target" repoclosure --json' "$helper"

# Behavioral contract for repoclosure classification. DNF5 documents rc=1 as
# the unresolved-dependency result; valid non-empty JSON must therefore become
# BLOCKED while malformed output / command failures remain errors.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# shellcheck disable=SC1090
source "$helper"

printf '[]\n' >"$tmp/clear.json"
[[ "$(fedora_upgrade_classify_repoclosure 0 "$tmp/clear.json")" == CLEAR ]]

printf '[{"package":"broken-1-1.x86_64","repo":"fedora","unresolved_dependencies":["libmissing.so.1()(64bit)"]}]\n' >"$tmp/blocked.json"
[[ "$(fedora_upgrade_classify_repoclosure 1 "$tmp/blocked.json")" == BLOCKED ]]

if fedora_upgrade_classify_repoclosure 1 "$tmp/clear.json" >/dev/null 2>&1; then
  printf 'FAIL: rc=1 with empty JSON must be a mechanism error\n' >&2
  exit 1
fi
printf 'not-json\n' >"$tmp/invalid.json"
if fedora_upgrade_classify_repoclosure 1 "$tmp/invalid.json" >/dev/null 2>&1; then
  printf 'FAIL: malformed repoclosure output must be a mechanism error\n' >&2
  exit 1
fi
if fedora_upgrade_classify_repoclosure 2 "$tmp/clear.json" >/dev/null 2>&1; then
  printf 'FAIL: repoclosure execution/parser failure must be a mechanism error\n' >&2
  exit 1
fi

# Exercise the probe itself with a fake dnf5 command: expected incompatibility
# is BLOCKED+success; inaccessible/broken mechanism is non-zero.
mkdir -p "$tmp/bin"
cat >"$tmp/bin/dnf5" <<'EOF'
#!/usr/bin/env bash
case "${FAKE_REPOCLOSURE_MODE:-clear}" in
  clear)
    printf '[]\n'
    exit 0
    ;;
  blocked)
    printf '[{"package":"broken-1-1.x86_64","repo":"fedora","unresolved_dependencies":["libmissing.so.1()(64bit)"]}]\n'
    exit 1
    ;;
  inaccessible)
    printf 'Failed to download repository metadata\n' >&2
    exit 1
    ;;
  parser)
    printf 'unknown option\n' >&2
    exit 2
    ;;
esac
EOF
chmod +x "$tmp/bin/dnf5"
real_path="$PATH"
export PATH="$tmp/bin:$PATH"

FAKE_REPOCLOSURE_MODE=blocked
export FAKE_REPOCLOSURE_MODE
fedora_upgrade_repoclosure_probe 45 "$tmp/probe.json" "$tmp/probe.err" "$tmp/probe.status"
grep -Fxq BLOCKED "$tmp/probe.status"

FAKE_REPOCLOSURE_MODE=inaccessible
export FAKE_REPOCLOSURE_MODE
if fedora_upgrade_repoclosure_probe 45 "$tmp/probe.json" "$tmp/probe.err" "$tmp/probe.status"; then
  printf 'FAIL: inaccessible repository must fail the mechanism\n' >&2
  exit 1
fi

FAKE_REPOCLOSURE_MODE=parser
export FAKE_REPOCLOSURE_MODE
if fedora_upgrade_repoclosure_probe 45 "$tmp/probe.json" "$tmp/probe.err" "$tmp/probe.status"; then
  printf 'FAIL: repoclosure parser failure must fail the mechanism\n' >&2
  exit 1
fi
export PATH="$real_path"

grep -Fq 'test_fedora_upgrade_lifecycle_contract.sh' "$ROOT/.github/workflows/tests.yml"

printf 'PASS: Fedora N+1 lifecycle distinguishes BLOCKED readiness from mechanism ERROR\n'

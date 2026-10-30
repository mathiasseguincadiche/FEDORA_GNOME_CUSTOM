#!/usr/bin/env bash
# Emergency return to Fedora kernels run for real in a repository copy with
# fake dnf5/rpm/grubby/mokutil, also with Secure Boot enabled (only the signed
# Fedora kernel can then boot): it needs the exact confirmation, disables both
# upstream COPRs, clears the versionlock, distro-syncs only from fedora/updates
# and selects the newest Fedora kernel; every failure says why and leaves the
# GRUB default unchanged. The kernel module refuses to relax the Secure Boot
# block that the install engine always enforces.
# shellcheck disable=SC2016,SC1090,SC1091,SC2015
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "kernel recovery behavior: FAIL: $*" >&2; exit 1; }
[[ "$EUID" != 0 ]] || { echo 'kernel recovery behavior: SKIP (the script refuses root by design)'; exit 0; }

fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/home" "$tmp/boot"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home" T_LOG="$tmp/calls" T_TMP="$tmp" KERNEL_BOOT_DIR="$tmp/boot" FEDORA_OS_RELEASE_FILE="$tmp/os-release"
unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_RUNTIME_DIR
printf 'ID=fedora\nVERSION_ID=44\n' > "$FEDORA_OS_RELEASE_FILE"
printf 'ID=fedora\nVERSION_ID=43\n' > "$tmp/os-43"
source "$ROOT/lib/constants.sh"
# Fedora 45 is not promoted yet: the recovery runs on the selected Fedora 44 lab release.
printf 'HOST_RELEASE="44"\n' > "$fixture/config/local.conf"
cat >> "$fixture/lib/apply_gate.sh" <<'SH'
runtime_environment_detect() { echo "${T_RUNTIME:-baremetal}"; }
SH

fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
fake sudo 'printf "sudo %s\n" "$*" >> "$T_LOG"
case "$1 $2" in
  "dnf5 -y") [[ "$*" != *"copr disable"* || -z "${T_COPR_FAIL:-}" ]] || exit 1
             [[ "$*" != *distro-sync* ]] || { [[ -z "${T_SYNC_FAIL:-}" ]] || exit 1; printf "%s\n" ${T_AFTER_SYNC:-7.1.9-200.fc44.x86_64} > "$T_TMP/kernels"; } ;;
  "grubby --set-default") [[ -n "${T_GRUBBY_STUCK:-}" ]] || printf "%s\n" "$3" > "$T_TMP/grub-default" ;;
esac'
fake rpm 'case "$1" in
  -qa) printf "%s\n" kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra perf ;;
  -q) cat "$T_TMP/kernels" ;;
esac'
fake grubby '[[ "$1" == --default-kernel ]] && cat "$T_TMP/grub-default"'
fake mokutil 'echo "SecureBoot ${T_SB:-disabled}"'
fake dnf5 ':'
export PATH="$tmp/bin:$PATH"

reset() {
  printf '%s\n' 7.2.9-200.vanilla.fc44.x86_64 7.2.8-200.vanilla.fc44.x86_64 > "$tmp/kernels"
  printf '%s/vmlinuz-7.2.9-200.vanilla.fc44.x86_64\n' "$tmp/boot" > "$tmp/grub-default"
  touch "$tmp/boot/vmlinuz-7.1.9-200.fc44.x86_64"
  rm -f "$T_LOG"
}
recover() { # recover ANSWER [VAR=VALUE...] : runs the real script, output in $tmp/out
  local answer="$1"; shift
  printf '%s\n' "$answer" | env "$@" bash "$fixture/scripts/kernel/rollback-to-fedora.sh" > "$tmp/out" 2>&1
}
default_unchanged() { [[ "$(<"$tmp/grub-default")" == "$tmp/boot/vmlinuz-7.2.9-200.vanilla.fc44.x86_64" ]]; }
refused() { # refused RC MESSAGE WHY ANSWER [VAR=VALUE...]
  local expected="$1" message="$2" why="$3" answer="$4" rc=0; shift 4
  reset; recover "$answer" "$@" || rc=$?
  [[ "$rc" == "$expected" ]] && grep -Fq -- "$message" "$tmp/out" && default_unchanged \
    || { cat "$tmp/out" >&2; fail "$why: expected rc=$expected with '$message', got $rc"; }
}

# Happy path: exact confirmation, both COPRs disabled, lock cleared, Fedora-only sync, newest Fedora kernel default.
reset
recover 'ROLLBACK FEDORA KERNEL' || { cat "$tmp/out" >&2; fail 'recovery refused on a valid host'; }
expected="sudo dnf5 -y copr disable @kernel-vanilla/stable|sudo dnf5 -y copr disable @kernel-vanilla/fedora\
|sudo python3 $fixture/scripts/kernel/pin-upstream-target.py --clear\
|sudo dnf5 -y --repo=fedora --repo=updates --setopt=allow_vendor_change=1 distro-sync kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra perf\
|sudo grubby --set-default $tmp/boot/vmlinuz-7.1.9-200.fc44.x86_64"
[[ "$(paste -sd'|' "$T_LOG")" == "$expected" ]] || fail "unexpected recovery: $(paste -sd'|' "$T_LOG")"
grep -Fq 'Fedora kernel 7.1.9-200.fc44.x86_64 selected' "$tmp/out" || fail 'recovery did not report the selected kernel'
# Several Fedora kernels: the newest one of the selected release wins.
reset
recover 'ROLLBACK FEDORA KERNEL' T_AFTER_SYNC='7.0.4-100.fc44.x86_64 7.1.9-200.fc44.x86_64 7.3.1-100.fc45.x86_64' || fail 'recovery with several Fedora kernels refused'
[[ "$(<"$tmp/grub-default")" == "$tmp/boot/vmlinuz-7.1.9-200.fc44.x86_64" ]] || fail "wrong Fedora kernel selected: $(<"$tmp/grub-default")"

# Refusals before any change.
refused 2 'Cancelled.' 'an approximate confirmation' 'rollback fedora kernel'
[[ ! -e "$T_LOG" ]] || fail "cancelled recovery changed the host: $(paste -sd'|' "$T_LOG")"
refused "$EXIT_SECURITY_BLOCK" 'Kernel mutations are bare-metal only' 'a VM' 'ROLLBACK FEDORA KERNEL' T_RUNTIME=vm
refused 20 'not the selected Fedora 44 release' 'another Fedora release' 'ROLLBACK FEDORA KERNEL' FEDORA_OS_RELEASE_FILE="$tmp/os-43"
refused 40 'cannot disable @kernel-vanilla/stable' 'a COPR that cannot be disabled' 'ROLLBACK FEDORA KERNEL' T_COPR_FAIL=1
grep -q distro-sync "$T_LOG" && fail 'distro-sync ran with an upstream COPR still enabled'
# Failures after the sync say why and never touch GRUB.
refused 40 'distro-sync from the Fedora repositories failed' 'a failed distro-sync' 'ROLLBACK FEDORA KERNEL' T_SYNC_FAIL=1
refused 40 'no Fedora 44 kernel-core is installed after distro-sync' 'no Fedora kernel after the sync' 'ROLLBACK FEDORA KERNEL' T_AFTER_SYNC=7.2.9-200.vanilla.fc44.x86_64
grep -q 'grubby --set-default' "$T_LOG" && fail 'GRUB changed without a Fedora kernel'
reset; rm "$tmp/boot/vmlinuz-7.1.9-200.fc44.x86_64"; rc=0; recover 'ROLLBACK FEDORA KERNEL' || rc=$?
[[ "$rc" == 40 ]] && grep -Fq 'boot image missing for 7.1.9-200.fc44.x86_64' "$tmp/out" && default_unchanged || fail "missing boot image not reported (rc=$rc)"
refused 40 'GRUB default is 7.2.9-200.vanilla.fc44.x86_64, not 7.1.9-200.fc44.x86_64' 'a GRUB default that did not change' 'ROLLBACK FEDORA KERNEL' T_GRUBBY_STUCK=1
# Secure Boot enabled: only the signed Fedora kernel can boot, so the recovery
# towards it stays available (ADR 0020).
reset
recover 'ROLLBACK FEDORA KERNEL' T_SB=enabled || { cat "$tmp/out" >&2; fail 'recovery to the signed Fedora kernel refused with Secure Boot enabled'; }
[[ "$(<"$tmp/grub-default")" == "$tmp/boot/vmlinuz-7.1.9-200.fc44.x86_64" ]] || fail 'Fedora kernel not selected with Secure Boot enabled'

# The kernel module refuses to relax the Secure Boot block the install engine enforces.
bash -s "$fixture" <<'MODULE' || fail "kernel module Secure Boot precheck (rc=$?)"
  set -Eeuo pipefail
  fixture="$1"
  cd "$fixture"; REPO_ROOT="$fixture"
  source lib/bootstrap.sh; engine_load_libraries; config_load
  log_error() { printf '%s\n' "$*" >> "$T_TMP/module.log"; }
  source modules/system/01a_kernel_latest_stable.sh
  system_kernel_precheck || exit 91
  rc=0; KERNEL_BLOCK_SECURE_BOOT=false system_kernel_precheck || rc=$?
  [[ "$rc" == "$EXIT_CONFIG_FAILED" ]] && grep -Fq 'KERNEL_BLOCK_SECURE_BOOT must stay true' "$T_TMP/module.log" || exit 92
  for state in enabled; do
    rc=0; T_SB="$state" system_kernel_precheck || rc=$?
    [[ "$rc" == "$EXIT_SECURITY_BLOCK" ]] || exit 93
  done
MODULE

echo 'kernel recovery behavior: PASS'

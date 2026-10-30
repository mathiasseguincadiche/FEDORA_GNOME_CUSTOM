#!/usr/bin/env bash
# The Golden HOST policy doctor run for real in a repository copy with fake
# mokutil/lsblk/dmsetup/sudo: a non-encrypted bare-metal host with Secure Boot
# off passes, including the default btrfs install where dmsetup only answers
# "No devices found"; any active crypt target, crypttab entry or crypt block
# device is refused; unreadable device-mapper tables are a warning, never OK.
# shellcheck disable=SC2016,SC1090,SC1091,SC2015
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "host security policy behavior: FAIL: $*" >&2; exit 1; }
fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/home" "$tmp/etc"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home" T_TMP="$tmp"
cat >> "$fixture/lib/apply_gate.sh" <<'SH'
runtime_environment_detect() { echo "${T_RUNTIME:-baremetal}"; }
SH
sed -i 's|/etc/crypttab|$T_TMP/etc/crypttab|g' "$fixture/diagnostics/host-security-policy-doctor"
grep -Fq '$T_TMP/etc/crypttab' "$fixture/diagnostics/host-security-policy-doctor" || fail 'cannot redirect /etc/crypttab'
fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
fake mokutil 'echo "SecureBoot ${T_SB:-disabled}"'
fake lsblk 'printf "%s\n" disk part part ${T_LSBLK_CRYPT:+crypt}'
# dmsetup: as a normal user the tables are unreadable unless T_DM_USER is set;
# T_DM selects what root sees.
fake dmsetup '[[ -n "${T_DM_ROOT:-}" || -n "${T_DM_USER:-}" ]] || { echo "/dev/mapper/control: open failed: Permission denied" >&2; exit 1; }
case "${T_DM:-none}" in
  none) echo "No devices found" ;;
  crypt) echo "luks-1234: 0 1953521664 crypt aes-xts-plain64 :64:logon:cryptsetup:1234-d0 0 259:2 32768" ;;
  empty) ;;
esac'
fake sudo '[[ "$1" == -n ]] && shift; [[ -z "${T_NO_SUDO:-}" ]] || exit 1; T_DM_ROOT=1 exec "$@"'
export PATH="$tmp/bin:$PATH"
doctor() { env "$@" bash "$fixture/diagnostics/host-security-policy-doctor" > "$tmp/out" 2>&1; }
passes() { doctor "$@" || { cat "$tmp/out" >&2; fail "compliant host refused ($*)"; }; }
refused() { local why="$1" rc=0; shift; doctor "$@" || rc=$?; [[ "$rc" == 40 ]] || { cat "$tmp/out" >&2; fail "$why accepted (rc=$rc)"; }; }

: > "$tmp/etc/crypttab"
passes                       # default btrfs install: dmsetup has no device at all
grep -Eq '^\[OK  \] device-mapper crypt' "$tmp/out" || fail 'no-device answer not reported as OK'
passes T_DM=empty            # device-mapper devices exist, none is crypt
passes T_DM_USER=1           # tables readable without sudo
refused 'an active crypt target' T_DM=crypt
refused 'an active crypt target read without sudo' T_DM=crypt T_DM_USER=1
refused 'Secure Boot enabled' T_SB=enabled
refused 'an active crypt block device' T_LSBLK_CRYPT=1
printf 'luks-1234 UUID=1234 none discard\n' > "$tmp/etc/crypttab"; refused 'a crypttab entry'
printf '# comment only\n\n' > "$tmp/etc/crypttab"; passes
# Unreadable device-mapper tables: a warning, never an OK proof.
doctor T_NO_SUDO=1 || fail 'unreadable device-mapper tables blocked the doctor'
grep -Eq '^\[WARN\] device-mapper crypt.*unreadable' "$tmp/out" || fail 'unreadable device-mapper tables reported as proof'
# Outside bare metal the firmware state is deferred.
doctor T_RUNTIME=vm T_SB=enabled && grep -Eq '^\[WARN\] Secure Boot runtime' "$tmp/out" || fail 'VM Secure Boot state not deferred'

echo 'host security policy behavior: PASS'

#!/usr/bin/env bash
# kernel-doctor run for real in a repository copy whose kernel inventory is a
# fixture: a healthy rolling N/N-1 host passes, and an unreachable kernel.org is
# a warning outside certification (record-suspend runs it right after resume,
# often before the network is back) but blocks --certify.
# shellcheck disable=SC2016,SC1090,SC1091,SC2015
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "kernel doctor behavior: FAIL: $*" >&2; exit 1; }
fixture="$tmp/repo"
mkdir -p "$fixture" "$tmp/bin" "$tmp/home" "$tmp/boot"
(cd "$ROOT" && git ls-files -z | xargs -0 cp --parents -t "$fixture")
export HOME="$tmp/home" KERNEL_BOOT_DIR="$tmp/boot"
N=7.2.9-200.vanilla.fc45.x86_64 N1=7.2.8-200.vanilla.fc45.x86_64 F=7.1.9-200.fc45.x86_64
touch "$tmp/boot/vmlinuz-$F"
cat >> "$fixture/lib/kernel_lifecycle.sh" <<SH
kernel_lifecycle_installed_all_releases() { printf '%s\n' $F $N1 $N; }
kernel_lifecycle_default_release() { echo $N; }
kernel_lifecycle_dnf_limit() { kernel_lifecycle_dnf_installonly_target; }
kernel_lifecycle_upstream_latest() { [[ -n "\${T_UPSTREAM-7.2.9}" ]] && echo "\${T_UPSTREAM-7.2.9}"; }
kernel_lifecycle_latest_available() { echo $N; }
kernel_lifecycle_secure_boot_state() { echo disabled; }
kernel_journal_require_clean() { return 0; }
SH
fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
fake uname "[[ \"\$1\" == -r ]] && echo $N || command -p uname \"\$@\""
fake rpm 'exit 1'
fake grubby 'exit 0'
fake lspci 'echo "	Kernel driver in use: xe"'
export PATH="$tmp/bin:$PATH"
doctor() { bash "$fixture/diagnostics/kernel-doctor" > "$tmp/out" 2>&1; }

doctor || { cat "$tmp/out" >&2; fail 'healthy rolling N/N-1 host refused'; }
bash "$fixture/diagnostics/kernel-doctor" --certify > "$tmp/out" 2>&1 || { cat "$tmp/out" >&2; fail 'healthy host refused by --certify'; }
# kernel.org unreachable: a warning for status and suspend cycles, a blocker for certification.
T_UPSTREAM='' bash "$fixture/diagnostics/kernel-doctor" --quiet || fail 'unreachable kernel.org blocked a non-certification run'
T_UPSTREAM='' bash "$fixture/diagnostics/kernel-doctor" > "$tmp/out" 2>&1 && grep -Eq '^\[WARN\] Latest stable' "$tmp/out" || fail 'unreachable kernel.org not reported as a warning'
if T_UPSTREAM='' bash "$fixture/diagnostics/kernel-doctor" --quiet --certify; then fail 'certification passed without proving the latest stable kernel'; fi
# A known newer kernel.org release is a warning in both modes (run a system update).
T_UPSTREAM=7.2.10 bash "$fixture/diagnostics/kernel-doctor" --quiet --certify || fail 'a newer upstream release blocked the run instead of warning'

echo 'kernel doctor behavior: PASS'

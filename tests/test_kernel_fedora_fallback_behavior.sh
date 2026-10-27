#!/usr/bin/env bash
# Real helper execution: upstream N/N-1 retention never removes the Fedora
# fallback, never removes the running kernel, and the fallback install lifts
# then restores the upstream versionlock.
# shellcheck disable=SC2317,SC2034
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
export FAKE_LOG="$tmp/calls.log" FAKE_RPM="$tmp/rpm.db"
: > "$FAKE_LOG"

# Installed kernels: name<TAB>release, one line per installonly package.
write_db() {
  : > "$FAKE_RPM"
  local release name
  for release in "$@"; do
    for name in kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra; do
      printf '%s\t%s\n' "$name" "$release" >> "$FAKE_RPM"
    done
  done
  printf 'kernel-headers\t%s\n' "${HEADERS_RELEASE:-7.2.0-100.fc45.x86_64}" >> "$FAKE_RPM"
}

cat > "$tmp/bin/rpm" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == -qa ]]; then
  cat "$FAKE_RPM"
else
  awk -F'\t' '$1=="kernel-core" {print $2}' "$FAKE_RPM"
fi
SH
cat > "$tmp/bin/dnf5" <<'SH'
#!/usr/bin/env bash
printf 'dnf5 %s\n' "$*" >> "$FAKE_LOG"
if [[ "$1 $2" == '-y remove' ]]; then
  shift 2
  awk -F'\t' 'NR==FNR {gone[$0]=1; next} !(($1 "-" $2) in gone)' <(printf '%s\n' "$@") "$FAKE_RPM" > "$FAKE_RPM.new"
  mv "$FAKE_RPM.new" "$FAKE_RPM"
elif [[ "$*" == *repoquery* ]]; then
  pkg="${*: -1}"
  for release in ${FAKE_FEDORA_AVAILABLE:-}; do
    if [[ "$*" == *'%{NAME}'* ]]; then printf '%s-%s\n' "$pkg" "$release"; else printf '%s\n' "$release"; fi
  done
fi
SH
cat > "$tmp/bin/sudo" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == python3 && "$2" == *pin-upstream-target.py ]]; then
  printf 'pin %s\n' "$3" >> "$FAKE_LOG"; exit 0
fi
if [[ "$1" == grubby ]]; then printf 'grubby %s\n' "$2" >> "$FAKE_LOG"; exit 0; fi
exec "$@"
SH
cat > "$tmp/bin/uname" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "${FAKE_RUNNING:-7.2.13-200.vanilla.fc45.x86_64}"
SH
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"

source "$ROOT/lib/constants.sh"
REPO_ROOT="$ROOT"
source "$ROOT/lib/kernel_lifecycle.sh"
command_exists() { command -v "$1" >/dev/null; }
ui_error() { printf 'ERROR %s\n' "$*" >&2; }
ui_check() { printf '%s %s %s\n' "$1" "$2" "$3"; }
kernel_lifecycle_set_latest_default() { printf 'set-latest-default\n' >> "$FAKE_LOG"; }
unset KERNEL_CHANNEL KERNEL_KEEP_FEDORA_FALLBACK

V1=7.2.11-200.vanilla.fc45.x86_64
V2=7.2.12-200.vanilla.fc45.x86_64
V3=7.2.13-200.vanilla.fc45.x86_64
F1=7.2.5-200.fc45.x86_64
F2=7.2.9-200.fc45.x86_64

# Classification: N/N-1 ignore Fedora kernels; the fallback is the newest Fedora one.
write_db "$F1" "$F2" "$V1" "$V2" "$V3"
[[ "$(kernel_lifecycle_latest_installed)" == "$V3" ]]
[[ "$(kernel_lifecycle_previous_installed)" == "$V2" ]]
[[ "$(kernel_lifecycle_installed_count)" == 3 ]]
[[ "$(kernel_lifecycle_fedora_fallback)" == "$F2" ]]
[[ "$(kernel_lifecycle_dnf_installonly_target)" == 4 ]]

# Prune: drop upstream older than N-1 and Fedora older than the fallback; keep headers.
FAKE_RUNNING="$V3" kernel_lifecycle_prune_old > "$tmp/prune.out"
removal="$(grep '^dnf5 -y remove' "$FAKE_LOG")"
grep -Fq "kernel-core-$V1" <<<"$removal"
grep -Fq "kernel-core-$F1" <<<"$removal"
if grep -Fq -e "$V2" -e "$V3" -e "$F2" -e kernel-headers <<<"$removal"; then
  echo 'prune removed a retained kernel or kernel-headers' >&2; exit 1
fi
if grep -Fq -- '--oldinstallonly' "$FAKE_LOG"; then echo 'oldinstallonly would drop the fallback' >&2; exit 1; fi

# The running kernel is never removed, even when it is outside the retained set.
: > "$FAKE_LOG"
write_db "$F1" "$F2" "$V2" "$V3"
FAKE_RUNNING="$F1" kernel_lifecycle_prune_old > "$tmp/prune-running.out"
grep -Fq "WARN Kernel retention $F1 is running" "$tmp/prune-running.out"
if grep -Fq "$F1" "$FAKE_LOG"; then echo 'running Fedora kernel was removed' >&2; exit 1; fi

# Fallback disabled: Fedora kernels are no longer retained (except a running one).
: > "$FAKE_LOG"
write_db "$F2" "$V2" "$V3"
KERNEL_KEEP_FEDORA_FALLBACK=false FAKE_RUNNING="$V3" kernel_lifecycle_prune_old > /dev/null
grep -Fq "kernel-core-$F2" "$FAKE_LOG"
[[ "$(KERNEL_KEEP_FEDORA_FALLBACK=false kernel_lifecycle_dnf_installonly_target)" == 3 ]]

# Ensure: a present fallback is left untouched, without any versionlock change.
: > "$FAKE_LOG"
write_db "$F2" "$V3"
kernel_lifecycle_ensure_fedora_fallback ensure > /dev/null
[[ ! -s "$FAKE_LOG" ]]

# Missing fallback: lift the pin, install the exact Fedora NEVRAs from fedora/updates,
# restore the pin to upstream N and keep upstream N as the GRUB default.
: > "$FAKE_LOG"
write_db "$V2" "$V3"
FAKE_FEDORA_AVAILABLE="$F1 $F2 $V3" kernel_lifecycle_ensure_fedora_fallback ensure > /dev/null
mapfile -t calls < "$FAKE_LOG"
[[ "${calls[0]}" == 'pin --clear' ]]
install_line="$(grep -n -- '--repo=fedora --repo=updates install' "$FAKE_LOG")"
grep -Fq "kernel-core-$F2" <<<"$install_line"
if grep -Fq -e "$F1" -e vanilla <<<"$install_line"; then echo 'wrong Fedora fallback release installed' >&2; exit 1; fi
pin_line="$(grep -n "^pin $V3$" "$FAKE_LOG" | cut -d: -f1)"
[[ -n "$pin_line" && "$pin_line" -gt "${install_line%%:*}" ]]
grep -Fxq 'set-latest-default' "$FAKE_LOG"

# Nothing available: fail closed and still restore the upstream pin.
: > "$FAKE_LOG"
rc=0
FAKE_FEDORA_AVAILABLE='' kernel_lifecycle_ensure_fedora_fallback ensure > /dev/null 2>&1 || rc=$?
[[ "$rc" == "$EXIT_POSTCHECK_FAILED" ]]
grep -Fxq "pin $V3" "$FAKE_LOG"
if grep -Fq ' install ' "$FAKE_LOG"; then echo 'install attempted without a Fedora kernel' >&2; exit 1; fi

echo 'kernel Fedora fallback behavior: PASS'

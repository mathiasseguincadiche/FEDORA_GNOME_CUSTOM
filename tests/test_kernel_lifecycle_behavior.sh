#!/usr/bin/env bash
# Real helper execution against fake rpm/dnf5/grubby: DNF retention, N-1
# rollback, Fedora fallback selection, the two-entry GRUB surface and the
# kernel module wiring. Fedora fallback install/prune is covered by
# test_kernel_fedora_fallback_behavior.sh.
# shellcheck disable=SC2317,SC2034,SC2329
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "kernel lifecycle behavior: FAIL: $*" >&2; exit 1; }
mkdir "$tmp/bin" "$tmp/boot"
export FAKE_LOG="$tmp/calls.log" FAKE_RPM="$tmp/rpm.db" FAKE_TMP="$tmp" KERNEL_BOOT_DIR="$tmp/boot"
: > "$FAKE_LOG"

# Installed kernel-core releases, one per line; a boot image is created for each.
write_db() {
  : > "$FAKE_RPM"
  local release
  for release in "$@"; do
    printf 'kernel-core\t%s\n' "$release" >> "$FAKE_RPM"
    touch "$tmp/boot/vmlinuz-$release"
  done
}

cat > "$tmp/bin/rpm" <<'SH'
#!/usr/bin/env bash
case "$*" in
  -qa*) cat "$FAKE_RPM" ;;
  *dracut-config-rescue*) [[ -e "$FAKE_TMP/rescue-pkg" ]] || { echo 'package dracut-config-rescue is not installed'; exit 1; } ;;
  *) awk -F'\t' '$1=="kernel-core" {print $2}' "$FAKE_RPM" ;;
esac
SH
cat > "$tmp/bin/dnf5" <<'SH'
#!/usr/bin/env bash
args="$*"
printf 'dnf5 %s\n' "$args" >> "$FAKE_LOG"
case "$args" in
  'config-manager setopt installonly_limit='*) [[ -e "$FAKE_TMP/dnf-stuck" ]] || printf '%s\n' "${args##*=}" > "$FAKE_TMP/dnf-limit" ;;
  --dump-main-config) printf 'installonly_limit = %s\n' "$(cat "$FAKE_TMP/dnf-limit" 2>/dev/null || echo 3)" ;;
  '-y remove dracut-config-rescue') rm -f "$FAKE_TMP/rescue-pkg" ;;
esac
SH
cat > "$tmp/bin/grubby" <<'SH'
#!/usr/bin/env bash
case "$1" in
  --default-kernel) cat "$FAKE_TMP/grub-default" 2>/dev/null ;;
  --set-default) printf 'grubby --set-default %s\n' "$2" >> "$FAKE_LOG"; printf '%s\n' "$2" > "$FAKE_TMP/grub-default" ;;
  --info=ALL) sed 's/.*/kernel="&"/' "$FAKE_TMP/grub-extra" 2>/dev/null ;;
  --remove-kernel=*)
    printf 'grubby %s\n' "$1" >> "$FAKE_LOG"
    grep -Fxv "${1#--remove-kernel=}" "$FAKE_TMP/grub-extra" > "$FAKE_TMP/grub-extra.new" || true
    mv "$FAKE_TMP/grub-extra.new" "$FAKE_TMP/grub-extra" ;;
esac
SH
cat > "$tmp/bin/sudo" <<'SH'
#!/usr/bin/env bash
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
runtime_is_baremetal() { [[ "${FAKE_RUNTIME:-baremetal}" == baremetal ]]; }
kernel_lifecycle_secure_boot_state() { printf '%s\n' "${FAKE_SECURE_BOOT:-disabled}"; }
kernel_lifecycle_write_state() { printf 'state %s\n' "$1" >> "$FAKE_LOG"; }
unset KERNEL_CHANNEL KERNEL_VANILLA_COPR KERNEL_KEEP_FEDORA_FALLBACK

V1=7.2.11-200.vanilla.fc45.x86_64
V2=7.2.12-200.vanilla.fc45.x86_64
V3=7.2.13-200.vanilla.fc45.x86_64
F2=7.2.9-200.fc45.x86_64
default_is() { [[ "$(kernel_lifecycle_default_release)" == "$1" ]]; }
expect_rc() {
  local want="$1" rc=0; shift
  "$@" > "$tmp/out" 2>&1 || rc=$?
  [[ "$rc" == "$want" ]] || { cat "$tmp/out" >&2; fail "$* returned $rc, expected $want"; }
}

# The shipped policy is the Golden N/N-1 retention.
[[ "$(kernel_lifecycle_max_installed)" == 2 ]] || fail 'shipped policy is not max_installed_kernels=2'

# DNF retention: N/N-1 + Fedora fallback + one install slot, verified after writing.
expect_rc 0 kernel_lifecycle_ensure_dnf_retention
[[ "$(cat "$tmp/dnf-limit")" == 4 ]] || fail 'installonly_limit is not 4 with the Fedora fallback'
rm -f "$tmp/dnf-limit"; touch "$tmp/dnf-stuck"
expect_rc "$EXIT_POSTCHECK_FAILED" kernel_lifecycle_ensure_dnf_retention
rm -f "$tmp/dnf-stuck"
printf 'max_installed_kernels=3\n' > "$tmp/policy"
kernel_lifecycle_policy_path() { printf '%s\n' "$tmp/policy"; }
: > "$FAKE_LOG"
expect_rc "$EXIT_CONFIG_FAILED" kernel_lifecycle_ensure_dnf_retention
[[ ! -s "$FAKE_LOG" ]] || fail 'DNF was reconfigured despite a non-Golden policy'
kernel_lifecycle_policy_path() { printf '%s/config/kernel-lifecycle.policy\n' "$REPO_ROOT"; }

# Rollback selects N-1 without removing anything; N stays installed.
write_db "$F2" "$V2" "$V3"
printf '%s\n' "$tmp/boot/vmlinuz-$V3" > "$tmp/grub-default"
: > "$FAKE_LOG"
expect_rc 0 kernel_lifecycle_rollback
default_is "$V2" || fail 'rollback did not make N-1 the GRUB default'
grep -Fxq 'state rollback-selected' "$FAKE_LOG" || fail 'rollback state not recorded'
if grep -q '^dnf5' "$FAKE_LOG"; then fail 'rollback touched packages'; fi

# Back to N.
expect_rc 0 kernel_lifecycle_set_latest_default
default_is "$V3" || fail 'latest kernel not restored as GRUB default'

# Rollback refuses without N-1, or when the N-1 boot image is gone.
write_db "$F2" "$V3"
expect_rc "$EXIT_PRECHECK_FAILED" kernel_lifecycle_rollback
write_db "$F2" "$V2" "$V3"; rm "$tmp/boot/vmlinuz-$V2"
expect_rc "$EXIT_POSTCHECK_FAILED" kernel_lifecycle_rollback
default_is "$V3" || fail 'failed rollback changed the GRUB default'

# Secure Boot enabled or unknown blocks every change towards an upstream kernel.
write_db "$F2" "$V2" "$V3"
FAKE_SECURE_BOOT=enabled expect_rc "$EXIT_SECURITY_BLOCK" kernel_lifecycle_rollback
FAKE_SECURE_BOOT=unknown expect_rc "$EXIT_SECURITY_BLOCK" kernel_lifecycle_rollback
FAKE_RUNTIME=vm expect_rc "$EXIT_SECURITY_BLOCK" kernel_lifecycle_rollback
FAKE_RUNTIME=vm expect_rc "$EXIT_SECURITY_BLOCK" kernel_lifecycle_select_fallback
default_is "$V3" || fail 'a blocked host changed the GRUB default'

# Fedora fallback selection makes the Fedora kernel the default, keeping N/N-1.
: > "$FAKE_LOG"
expect_rc 0 kernel_lifecycle_select_fallback
default_is "$F2" || fail 'Fedora fallback is not the GRUB default'
grep -Fxq 'state fallback-selected' "$FAKE_LOG" || fail 'fallback state not recorded'
[[ "$(kernel_lifecycle_installed_count)" == 2 ]] || fail 'upstream kernels changed while selecting the fallback'
# Selecting the signed Fedora kernel stays possible with Secure Boot enabled
# or unknown: it is the remedy when the unsigned upstream kernels cannot boot.
for state in enabled unknown; do
  write_db "$F2" "$V2" "$V3"; printf '%s\n' "$tmp/boot/vmlinuz-$V3" > "$tmp/grub-default"
  FAKE_SECURE_BOOT="$state" expect_rc 0 kernel_lifecycle_select_fallback
  default_is "$F2" || fail "Fedora fallback not selected with Secure Boot $state"
done
write_db "$V2" "$V3"
expect_rc "$EXIT_PRECHECK_FAILED" kernel_lifecycle_select_fallback

# GRUB surface: --check reports a rescue entry without changing anything.
write_db "$F2" "$V2" "$V3"
touch "$tmp/rescue-pkg"
printf '%s\n' /boot/vmlinuz-0-rescue-abc123 > "$tmp/grub-extra"
: > "$FAKE_LOG"
expect_rc "$EXIT_POSTCHECK_FAILED" kernel_lifecycle_enforce_grub_surface --check
[[ ! -s "$FAKE_LOG" ]] || fail '--check mutated the system'

# --apply removes the rescue package and entry through dnf5/grubby, then passes.
expect_rc 0 kernel_lifecycle_enforce_grub_surface --apply
grep -Fxq 'dnf5 -y remove dracut-config-rescue' "$FAKE_LOG" || fail 'rescue package not removed through dnf5'
grep -Fxq 'grubby --remove-kernel=/boot/vmlinuz-0-rescue-abc123' "$FAKE_LOG" || fail 'rescue entry not removed through grubby'
[[ ! -s "$tmp/grub-extra" ]] || fail 'rescue entry still present'
expect_rc 0 kernel_lifecycle_enforce_grub_surface --check

# Rescue entry without the package (e.g. regenerated by hand) is still removed.
printf '%s\n' /boot/vmlinuz-0-rescue-def456 > "$tmp/grub-extra"
expect_rc 0 kernel_lifecycle_enforce_grub_surface --apply
[[ ! -s "$tmp/grub-extra" ]] || fail 'stray rescue entry kept'

# More than N/N-1 upstream kernels, or a missing Fedora fallback, fail the surface.
write_db "$F2" "$V1" "$V2" "$V3"
expect_rc "$EXIT_POSTCHECK_FAILED" kernel_lifecycle_enforce_grub_surface --check
write_db "$V2" "$V3"
expect_rc "$EXIT_POSTCHECK_FAILED" kernel_lifecycle_enforce_grub_surface --check
KERNEL_KEEP_FEDORA_FALLBACK=false expect_rc 0 kernel_lifecycle_enforce_grub_surface --check

# The kernel module installs N then enforces the GRUB surface, both as mutations.
run_mutating() { shift; printf 'mutate %s\n' "$*" >> "$FAKE_LOG"; }
is_true() { [[ "$1" == true ]]; }
# shellcheck source=/dev/null
source "$ROOT/modules/system/01a_kernel_latest_stable.sh"
: > "$FAKE_LOG"
system_kernel_apply
mapfile -t calls < "$FAKE_LOG"
[[ "${calls[0]}" == "mutate bash $ROOT/scripts/kernel/kernel-lifecycle.sh install-latest" ]] || fail "module did not install N first: ${calls[0]:-none}"
[[ "${calls[1]}" == "mutate bash $ROOT/scripts/kernel/enforce-two-entry-grub.sh --apply" ]] || fail "module did not enforce GRUB after install: ${calls[1]:-none}"
: > "$FAKE_LOG"
ENABLE_KERNEL_VANILLA_STABLE=false system_kernel_apply
[[ ! -s "$FAKE_LOG" ]] || fail 'disabled kernel module still mutated the system'

echo 'kernel lifecycle behavior: PASS'

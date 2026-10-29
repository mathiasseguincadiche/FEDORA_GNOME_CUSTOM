#!/usr/bin/env bash
# Kernel lifecycle specification: the Golden policy values, the public
# commands and the forbidden deletion paths. Behaviour is exercised by
# test_kernel_lifecycle_behavior.sh and test_kernel_fedora_fallback_behavior.sh.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "kernel lifecycle contract: FAIL: $*" >&2; exit 1; }

policy="$ROOT/config/kernel-lifecycle.policy"
for setting in mode=rolling-n-nminus1 track=latest-stable install_latest_direct=true \
  max_installed_kernels=2 keep_previous=true keep_fedora_fallback=true rescue_entry_enabled=false \
  one_shot_test_boot=false preboot_certification_required=false post_update_recertification=true \
  required_suspend_cycles=5; do
  grep -Fxq "$setting" "$policy" || fail "policy setting missing: $setting"
done
grep -Fxq 'KERNEL_CHANNEL	vanilla' "$ROOT/config/schema-enums.tsv" || fail 'vanilla is not the only kernel channel'
(
  set +u
  source "$ROOT/config/kernel.conf"
  [[ "$KERNEL_REQUIRE_LATEST_STABLE" == true && "$KERNEL_KEEP_FEDORA_FALLBACK" == true && "$KERNEL_BLOCK_SECURE_BOOT" == true ]]
) || fail 'kernel.conf must require latest stable, keep the Fedora fallback and block Secure Boot'

# Every lifecycle action is reachable through ./control.sh kernel ACTION.
usage="$(sed -n "s/.*Usage: kernel-lifecycle.sh \[\(.*\)\].*/\1/p" "$ROOT/scripts/kernel/kernel-lifecycle.sh")"
route="$(sed -n '/^    kernel)$/,/^      ;;$/p' "$ROOT/lib/control_center.sh")"
IFS='|' read -r -a actions <<<"$usage"
(( ${#actions[@]} >= 6 )) || fail 'cannot read kernel-lifecycle.sh actions'
for action in "${actions[@]}" rollback-fedora; do
  grep -Eq "(^|[ |])${action}[|)]" <<<"$route" || fail "./control.sh kernel $action is not routed"
done

# Kernels leave through DNF5 with exact NEVRAs; no raw erasure or /boot deletion.
if grep -RInE 'rpm[[:space:]]+-e|rm[[:space:]].*/boot|unlink[[:space:]].*/boot|dnf5?[[:space:]].*remove[[:space:]].*kernel-[0-9]|--oldinstallonly' \
  "$ROOT/lib/kernel_lifecycle.sh" "$ROOT/scripts/kernel" "$ROOT/modules/system/01a_kernel_latest_stable.sh" \
  "$ROOT/scripts/maintenance/update-system.sh" | grep -Ev '^[^:]+:[0-9]+:[[:space:]]*#'; then
  fail 'unsafe direct kernel deletion found'
fi

echo 'kernel rolling N/N-1 lifecycle contract: PASS'

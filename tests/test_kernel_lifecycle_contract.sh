#!/usr/bin/env bash
# shellcheck disable=SC2016
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

conf="$ROOT/config/kernel.conf"
policy="$ROOT/config/kernel-lifecycle.policy"
lib="$ROOT/lib/kernel_lifecycle.sh"
entry="$ROOT/scripts/kernel/kernel-lifecycle.sh"
rescue="$ROOT/scripts/kernel/enforce-two-entry-grub.sh"
module="$ROOT/modules/system/01a_kernel_latest_stable.sh"
doctor="$ROOT/diagnostics/kernel-doctor"
control="$ROOT/control.sh"
updater="$ROOT/scripts/maintenance/update-system.sh"

for file in "$conf" "$policy" "$lib" "$entry" "$rescue" "$module" "$doctor" "$control" "$updater"; do
  [[ -s "$file" ]] || { echo "missing kernel lifecycle file: $file" >&2; exit 1; }
done

grep -Fxq 'mode=rolling-n-nminus1' "$policy"
grep -Fxq 'track=latest-stable' "$policy"
grep -Fxq 'install_latest_direct=true' "$policy"
grep -Fxq 'max_installed_kernels=2' "$policy"
grep -Fxq 'keep_previous=true' "$policy"
grep -Fxq 'keep_fedora_fallback=false' "$policy"
grep -Fxq 'rescue_entry_enabled=false' "$policy"
grep -Fxq 'one_shot_test_boot=false' "$policy"
grep -Fxq 'preboot_certification_required=false' "$policy"
grep -Fxq 'post_update_recertification=true' "$policy"
grep -Fxq 'required_suspend_cycles=5' "$policy"
grep -Fq 'KERNEL_REQUIRE_LATEST_STABLE="true"' "$conf"
grep -Fq 'KERNEL_KEEP_FEDORA_FALLBACK="false"' "$conf"
grep -Fq 'latest stable Kernel Vanilla release directly' "$conf"

grep -Fq 'kernel_lifecycle_max_installed' "$lib"
grep -Fq 'kernel_lifecycle_prepare_rolling_update' "$lib"
grep -Fq 'kernel_lifecycle_finalize_update' "$lib"
grep -Fq 'kernel_lifecycle_previous_installed' "$lib"
grep -Fq 'dnf5 config-manager setopt "installonly_limit=$limit"' "$lib"
grep -Fq 'remove --oldinstallonly --limit="$limit"' "$lib"
grep -Fq 'grubby --set-default' "$lib"
grep -Fq 'installed=$count max=$limit' "$lib"
grep -Fq 'rolling N/N-1 max=2' "$doctor"
grep -Fq 'GRUB rescue' "$doctor"
grep -Fq 'N-1' "$doctor"
grep -Fq 'run a complete system update' "$doctor"
grep -Fq 'kernel-lifecycle.sh" install-latest' "$module"
grep -Fq 'retain only N/N-1' "$module"
grep -Fq 'enforce-two-entry-grub.sh" --apply' "$module"
grep -Fq 'enforce-two-entry-grub.sh" --check' "$module"

grep -Fq 'dnf5 -y remove dracut-config-rescue' "$rescue"
grep -Fq 'grubby --remove-kernel="$kernel"' "$rescue"
grep -Fq 'vmlinuz-0-rescue-' "$rescue"
grep -Fq 'More than two kernel-core versions are installed' "$rescue"
if grep -Eq 'rm[[:space:]].*/boot|unlink[[:space:]].*/boot' "$rescue"; then
  echo 'rescue cleanup must use bootloader/package tooling, not direct /boot deletion' >&2
  exit 1
fi

grep -Fq 'source "$REPO_ROOT/lib/kernel_lifecycle.sh"' "$updater"
grep -Fq 'kernel_lifecycle_prepare_rolling_update' "$updater"
grep -Fq 'kernel_lifecycle_finalize_update' "$updater"
grep -Fq 'kernel_target=' "$updater"
grep -Fq 'kernel_max_installed=' "$updater"
grep -Fq 'LATEST STABLE KERNEL TARGET=' "$updater"

for action in install-latest prune rollback; do
  grep -Fq "$action" "$entry" || { echo "missing lifecycle action: $action" >&2; exit 1; }
  grep -Fq "$action" "$control" || { echo "control.sh does not expose lifecycle action: $action" >&2; exit 1; }
done

grep -Fq 'rollback-fedora' "$control"

for stale in 'candidate.env' 'certified.env' 'previous-certified.env' 'grub2-reboot' 'kernel_lifecycle_certify_candidate' 'kernel_lifecycle_schedule_candidate_once'; do
  if grep -Fq "$stale" "$lib" "$entry" "$module"; then
    echo "stale candidate/certified lifecycle remains: $stale" >&2
    exit 1
  fi
done

# Kernel removal is allowed only through DNF5 installonly retention; raw package
# erasure or direct /boot deletion remains forbidden.
if grep -RInE 'rpm[[:space:]]+-e|rm[[:space:]].*/boot/vmlinuz|dnf5?[[:space:]].*remove[[:space:]].*kernel-[0-9]' "$lib" "$entry" "$module" "$updater" "$rescue"; then
  echo 'unsafe direct kernel deletion found' >&2
  exit 1
fi

echo 'kernel rolling N/N-1 lifecycle contract: PASS'

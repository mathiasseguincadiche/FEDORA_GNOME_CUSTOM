#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/kernel_lifecycle.sh"

mode="${1:---apply}"
case "$mode" in
  --apply|--check) ;;
  *) echo 'Usage: enforce-two-entry-grub.sh [--apply|--check]' >&2; exit "$EXIT_USAGE" ;;
esac

runtime_is_baremetal || { ui_error 'GRUB kernel-retention enforcement is bare-metal only'; exit "$EXIT_SECURITY_BLOCK"; }
command_exists rpm || { ui_error 'rpm is required'; exit "$EXIT_PRECHECK_FAILED"; }
command_exists grubby || { ui_error 'grubby is required'; exit "$EXIT_PRECHECK_FAILED"; }

limit="$(kernel_lifecycle_max_installed)"
[[ "$limit" == 2 ]] || { ui_error "Golden policy requires exactly two normal kernel entries; max=$limit"; exit "$EXIT_CONFIG_FAILED"; }

rescue_entries() {
  grubby --info=ALL 2>/dev/null \
    | awk -F= '$1=="kernel" {gsub(/"/, "", $2); if ($2 ~ /\/vmlinuz-0-rescue-/) print $2}' \
    | sort -u
}

if [[ "$mode" == --apply ]]; then
  if rpm -q dracut-config-rescue >/dev/null 2>&1; then
    command_exists dnf5 || { ui_error 'dnf5 is required to disable future rescue-image generation'; exit "$EXIT_PRECHECK_FAILED"; }
    sudo dnf5 -y remove dracut-config-rescue
  fi

  mapfile -t rescue < <(rescue_entries)
  for kernel in "${rescue[@]}"; do
    sudo grubby --remove-kernel="$kernel"
  done
fi

if rpm -q dracut-config-rescue >/dev/null 2>&1; then
  ui_error 'dracut-config-rescue is installed; Fedora may regenerate a third rescue boot entry'
  exit "$EXIT_POSTCHECK_FAILED"
fi

mapfile -t remaining_rescue < <(rescue_entries)
((${#remaining_rescue[@]} == 0)) || {
  ui_error "Rescue GRUB entry still present: ${remaining_rescue[*]}"
  exit "$EXIT_POSTCHECK_FAILED"
}

count="$(kernel_lifecycle_installed_count)"
(( count <= 2 )) || { ui_error "More than two kernel-core versions are installed: $count"; exit "$EXIT_POSTCHECK_FAILED"; }

ui_check OK 'GRUB N/N-1 surface' "rescue disabled; normal kernel-core versions=$count max=2"

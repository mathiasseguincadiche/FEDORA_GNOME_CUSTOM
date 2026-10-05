#!/usr/bin/env bash
# Fedora 44 -> promoted final Fedora 45. Preparation does not reboot.
set -Eeuo pipefail
umask 077
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/install_lock.sh"
install_lock_acquire || exit $?
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/kernel_lifecycle.sh"
action="${1:-plan}"
marker="$STATE_ROOT/fedora45-upgrade.env"
value() { evidence_marker_value "$marker" "$1" 2>/dev/null || true; }
write_state() {
  local phase="$1" target="$2" boot="$3"
  {
    printf 'schema=1\nphase=%s\nsource_release=44\ntarget_release=45\n' "$phase"
    printf 'commit=%s\neffective_config_sha256=%s\n' "$(repo_commit)" "$(effective_config_sha256)"
    printf 'source_boot_id=%s\nkernel_target=%s\n' "$boot" "$target"
    printf 'backup_snapshot=%s\n' "$(evidence_marker_value "$STATE_ROOT/last-full-backup.ok" snapshot)"
  } | evidence_atomic_write "$marker" 0600
}
require_identity() {
  [[ -s "$marker" && "$(value commit)" == "$(repo_commit)" &&
     "$(value effective_config_sha256)" == "$(effective_config_sha256)" ]] || {
    ui_error 'Upgrade state is absent or belongs to another commit/configuration.'
    return "$EXIT_SECURITY_BLOCK"
  }
  apply_gate_require_clean_git || return "$EXIT_SECURITY_BLOCK"
}
require_host() {
  runtime_is_baremetal || { ui_error 'Release upgrades require the physical HOST'; return "$EXIT_SECURITY_BLOCK"; }
  fedora_require_profile 45 || return "$EXIT_CONFIG_FAILED"
  kernel_lifecycle_require_host_gate || return $?
}
case "$action" in
  plan)
    printf 'Source: Fedora 44. Target: final promoted Fedora 45 / GNOME 51.\n'
    printf 'Steps: latest Fedora 44 update + reboot/finalize -> full Borg with cold VMs -> download -> reboot -> finalize -> requalify.\n'
    fedora_require_profile 45
    ;;
  prepare)
    require_host
    fedora_require_selected
    [[ "$(fedora_actual_release)" == 44 && "${HOST_RELEASE:-44}" == 44 ]] || exit "$EXIT_PRECHECK_FAILED"
    apply_gate_require_clean_git || exit "$EXIT_SECURITY_BLOCK"
    [[ "$(value phase)" != prepared && "$(value phase)" != reboot-requested ]] || {
      ui_error 'A release upgrade is already pending'; exit "$EXIT_SECURITY_BLOCK";
    }
    update_phase="$(evidence_marker_value "$STATE_ROOT/last-system-update.status" phase 2>/dev/null || true)"
    [[ "$update_phase" != prepared && "$update_phase" != reboot-requested ]] || {
      ui_error 'Finalize the Fedora 44 offline update before a release upgrade'; exit "$EXIT_SECURITY_BLOCK";
    }
    # DNF's documented precondition: the source OS must already be up to date.
    sudo dnf5 --refresh check-upgrade || {
      ui_error 'Source Fedora 44 updates remain or metadata cannot be checked. Update, reboot and finalize first.'
      exit "$EXIT_PRECHECK_FAILED"
    }
    kernel_lifecycle_ensure_tooling_and_repo
    kernel_lifecycle_ensure_dnf_retention
    target="$(KERNEL_DNF_RELEASE=45 kernel_lifecycle_resolve_latest_stable)"
    [[ "$target" == *.fc45.x86_64 ]] || exit "$EXIT_PRECHECK_FAILED"
    # Includes disks, XML, NVRAM and swtpm; refuses live VMs and insufficient staging.
    "$REPO_ROOT/scripts/backup/backup-now.sh" --include-vms
    "$REPO_ROOT/diagnostics/backup-doctor" --certify
    # No --allowerasing, --skip-unavailable or automatic reboot.
    sudo dnf5 --refresh --setopt=allow_vendor_change=1 system-upgrade download --releasever=45 -y
    sudo dnf5 offline status
    write_state prepared "$target" "$(cat /proc/sys/kernel/random/boot_id)"
    printf 'Fedora 45 transaction prepared. Review DNF output and run ./control.sh upgrade reboot when ready.\n'
    ;;
  reboot)
    require_host; require_identity
    [[ "$(fedora_actual_release)" == 44 && "$(value phase)" == prepared ]] || exit "$EXIT_PRECHECK_FAILED"
    backup_runtime_validate_full_marker "$STATE_ROOT/last-full-backup.ok" || exit "$EXIT_SECURITY_BLOCK"
    backup_runtime_full_vm_coverage_valid "$STATE_ROOT/last-full-backup.ok" || exit "$EXIT_SECURITY_BLOCK"
    "$REPO_ROOT/diagnostics/backup-doctor" --certify
    sudo dnf5 offline status
    write_state reboot-requested "$(value kernel_target)" "$(value source_boot_id)"
    sudo dnf5 system-upgrade reboot
    ;;
  finalize)
    require_host; require_identity
    phase="$(value phase)"
    [[ "$phase" == prepared || "$phase" == reboot-requested || "$phase" == activated ]] || exit "$EXIT_PRECHECK_FAILED"
    [[ "$(fedora_actual_release)" == 45 &&
       "$(cat /proc/sys/kernel/random/boot_id)" != "$(value source_boot_id)" ]] || exit "$EXIT_PRECHECK_FAILED"
    sudo dnf5 system-upgrade log --number=-1
    sudo dnf5 check
    (HOST_RELEASE=45; fedora_shell_matches "$(gnome-shell --version)")
    target="$(value kernel_target)"
    [[ "$(uname -r)" == "$target" ]] || {
      ui_error "Expected upstream kernel $target, running $(uname -r). Qualification remains blocked."
      exit "$EXIT_POSTCHECK_FAILED"
    }
    kernel_lifecycle_finalize_update "$target"
    # Preserve every existing local override; only HOST_RELEASE changes.
    overlay="$REPO_ROOT/config/local.conf"
    tmp="$(mktemp "$REPO_ROOT/config/.release-overlay.XXXXXX")"
    if [[ -r "$overlay" ]]; then awk '!/^HOST_RELEASE=/' "$overlay" > "$tmp"; fi
    printf 'HOST_RELEASE="45"\n' >> "$tmp"
    chmod 0600 "$tmp"
    mv -f "$tmp" "$overlay"
    config_load
    write_state activated "$target" "$(value source_boot_id)"
    "$REPO_ROOT/diagnostic.sh"
    write_state completed "$target" "$(value source_boot_id)"
    printf 'Fedora 45 / GNOME 51 upgrade checked. Previous Golden proofs are stale; repeat the three gates and hardware/restore qualification.\n'
    ;;
  status)
    if [[ -r "$marker" ]]; then cat "$marker"; else printf 'No Fedora 45 upgrade prepared.\n'; fi
    ;;
  *) echo 'Usage: ./control.sh upgrade plan|prepare|reboot|finalize|status' >&2; exit "$EXIT_USAGE" ;;
esac

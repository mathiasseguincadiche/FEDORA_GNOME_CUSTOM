#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="${1:---check}"

usage() {
  cat <<'USAGE'
Usage: scripts/lab/apply-gnome-virtualbox.sh [--plan|--apply|--check]

--plan   Show the exact GNOME LAB mutation scope.
--apply  Apply only the GNOME user-surface required by GATE 2.
--check  Run the read-only VirtualBox GNOME LAB doctor.

This entrypoint is accepted only inside Fedora 44 GNOME 50/Wayland running
under Oracle VirtualBox. It never opens the production bare-metal APPLY gate.
USAGE
}

case "$MODE" in
  --plan|--apply|--check) ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/modules/gnome/23_gnome_settings.sh"
source "$REPO_ROOT/modules/gnome/24_gnome_extensions.sh"
export LC_ALL=C

lab_require_virtualbox() {
  local vendor
  vendor="$(runtime_vm_vendor_detect || true)"
  if ! runtime_is_virtualbox; then
    ui_error "VIRTUALBOX GNOME LAB is forbidden; runtime=$(runtime_environment) vm_vendor=${vendor:-none}"
    return "$EXIT_SECURITY_BLOCK"
  fi
}

lab_require_fedora44() {
  if ! grep -Eq '^ID=fedora$|^ID="fedora"$' /etc/os-release || ! grep -Eq '^VERSION_ID="?44"?$' /etc/os-release; then
    ui_error 'VIRTUALBOX GNOME LAB requires Fedora Linux 44'
    return "$EXIT_PRECHECK_FAILED"
  fi
}

lab_require_gnome_session() {
  local shell_version
  [[ "$EUID" -ne 0 ]] || { ui_error 'Run the GNOME LAB as the logged-in desktop user, never as root'; return "$EXIT_SECURITY_BLOCK"; }
  [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] || { ui_error 'An active GNOME desktop session is required'; return "$EXIT_PRECHECK_FAILED"; }
  [[ "${XDG_SESSION_TYPE:-}" == wayland ]] || { ui_error "Wayland is required for GATE 2; detected ${XDG_SESSION_TYPE:-unknown}"; return "$EXIT_PRECHECK_FAILED"; }
  command_exists gnome-shell || { ui_error 'gnome-shell command missing'; return "$EXIT_PRECHECK_FAILED"; }
  shell_version="$(gnome-shell --version 2>/dev/null || true)"
  [[ "$shell_version" =~ GNOME[[:space:]]Shell[[:space:]]50([.]|$) ]] || {
    ui_error "GNOME Shell 50 required; detected ${shell_version:-unknown}"
    return "$EXIT_PRECHECK_FAILED"
  }
  [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] || { ui_error 'User D-Bus session is required'; return "$EXIT_PRECHECK_FAILED"; }
}

lab_plan() {
  cat <<'PLAN'
VIRTUALBOX GNOME LAB SCOPE
- Fedora 44 + GNOME Shell 50 + Wayland + Oracle VirtualBox are mandatory.
- Install only helper packages: curl, unzip, xdg-user-dirs, glib2.
- Apply GNOME window buttons: minimize, maximize, close on the right.
- Install pinned GNOME-reviewed Desktop Icons NG (DING) v95.
- Set XDG Desktop to ~/Bureau; show Trash; hide Home/external/network volumes.
- Install pinned GNOME-reviewed Show Desktop Plus v8.
- Configure top-left toggle-desktop button and Super+D.
- Enable DING and Show Desktop Plus in the current GNOME user session.
- Run a read-only LAB doctor and write a commit-bound LAB proof marker.

OUT OF SCOPE
- Production install.sh --apply and its bare-metal gate.
- Kernel, firmware, microcode, GPU/xe, storage/NVMe, KVM/libvirt, firewalld.
- Restic production backup/restore and bare-metal certification.
PLAN
}

lab_apply() {
  local ding_uuid="${DING_UUID:-ding@rastersoft.com}"
  local show_uuid="${SHOW_DESKTOP_PLUS_UUID:-show-desktop-plus@attentivecoder}"
  local proof

  command_exists sudo || { ui_error 'sudo is required to install the minimal LAB helper packages'; return "$EXIT_PRECHECK_FAILED"; }
  sudo dnf -y install curl unzip xdg-user-dirs glib2

  for cmd in curl unzip glib-compile-schemas gsettings gnome-extensions xdg-user-dirs-update; do
    command_exists "$cmd" || { ui_error "LAB dependency missing after package convergence: $cmd"; return "$EXIT_PRECHECK_FAILED"; }
  done

  DRY_RUN=false
  export DRY_RUN

  gnome_settings_precheck || return "$?"
  gnome_extensions_precheck || return "$?"

  gnome_settings_apply || return "$EXIT_APPLY_FAILED"

  run_mutating GNOME bash "$REPO_ROOT/scripts/gnome/install-ding.sh" \
    "${DING_SOURCE_URL:-}" "$ding_uuid" "${DING_SHELL_VERSION:-50}" || return "$EXIT_APPLY_FAILED"
  run_mutating GNOME bash "$REPO_ROOT/scripts/gnome/install-show-desktop-plus.sh" \
    "${SHOW_DESKTOP_PLUS_SOURCE_URL:-}" "$show_uuid" "${SHOW_DESKTOP_PLUS_SHELL_VERSION:-50}" || return "$EXIT_APPLY_FAILED"

  gnome_ding_settings_apply || return "$EXIT_APPLY_FAILED"
  gnome_show_desktop_plus_settings_apply || return "$EXIT_APPLY_FAILED"

  if ! gnome_extension_enable_checked 'Desktop Icons NG' "$ding_uuid"; then
    ui_error 'DING payload is installed but GNOME Shell did not expose it yet; log out/in and rerun --apply'
    return "$EXIT_POSTCHECK_FAILED"
  fi
  if ! gnome_extension_enable_checked 'Show Desktop Plus' "$show_uuid"; then
    ui_error 'Show Desktop Plus payload is installed but GNOME Shell did not expose it yet; log out/in and rerun --apply'
    return "$EXIT_POSTCHECK_FAILED"
  fi

  gnome_settings_postcheck || return "$EXIT_POSTCHECK_FAILED"
  "$REPO_ROOT/diagnostics/virtualbox-gnome-lab-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"

  proof="$STATE_ROOT/virtualbox-gnome-lab-$(repo_commit).ok"
  mkdir -p "$STATE_ROOT"
  printf 'commit=%s\nruntime=%s\nvm_vendor=%s\nutc=%s\n' \
    "$(repo_commit)" "$(runtime_environment)" "$(runtime_vm_vendor_detect)" "$(date -u +%FT%TZ)" > "$proof"
  ui_summary 'VIRTUALBOX GNOME LAB APPLY PASS' 'PROCEED TO THE MANUAL GATE 2 VISUAL CHECKLIST' "$proof" "$LOG_DIR"
}

lab_require_virtualbox || exit "$?"
lab_require_fedora44 || exit "$?"
lab_require_gnome_session || exit "$?"

case "$MODE" in
  --plan)
    lab_plan
    ;;
  --apply)
    lab_apply
    ;;
  --check)
    exec "$REPO_ROOT/diagnostics/virtualbox-gnome-lab-doctor"
    ;;
esac

#!/usr/bin/env bash
set -Eeuo pipefail

kvm_file_access_precheck() {
  is_true "${ENABLE_KVM:-true}" || return 0
  is_true "${VM_NAUTILUS_ACCESS_ENABLED:-true}" || return 0
  [[ -r "$REPO_ROOT/scripts/kvm/configure_nautilus_vm_access.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/${WINDOWS11_SMB_SETUP_SCRIPT:-guest/windows-11/configure-smb-share.ps1}" ]] || return "$EXIT_PRECHECK_FAILED"
}

kvm_file_access_plan() {
  cat <<'EOF'
GNOME / NAUTILUS VM FILE ACCESS:
- Ubuntu: expose the real guest filesystem to Nautilus through SFTP over the existing SSH service
- Windows: expose only C:\VM-Share through authenticated SMB; never expose the whole Windows filesystem
- discover current libvirt DHCP addresses dynamically and maintain two Nautilus bookmarks idempotently
- create a small FGC_TOOLS ISO containing the Windows SMB setup PowerShell script
- keep credentials out of Git and let GVfs/Nautilus request them interactively when required
- do not add a HOST directory sharing layer; file browsing is network-protocol based
EOF
}

kvm_file_access_apply() { :; }

kvm_file_access_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KVM:-true}" || return 0
  is_true "${VM_NAUTILUS_ACCESS_ENABLED:-true}" || return 0
  command_exists gio || return "$EXIT_POSTCHECK_FAILED"
  command_exists xorriso || return "$EXIT_POSTCHECK_FAILED"
  rpm -q gvfs gvfs-smb xorriso >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  [[ -r "$REPO_ROOT/scripts/kvm/configure_nautilus_vm_access.sh" ]] || return "$EXIT_POSTCHECK_FAILED"
  [[ -r "$REPO_ROOT/${WINDOWS11_SMB_SETUP_SCRIPT:-guest/windows-11/configure-smb-share.ps1}" ]] || return "$EXIT_POSTCHECK_FAILED"
}

#!/usr/bin/env bash
set -Eeuo pipefail

gnome_nautilus_precheck() {
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"
  case "${NAUTILUS_PREVIEW_POLICY:-local-only}" in
    always|local-only|never) ;;
    *)
      log_error GNOME "Unsupported Nautilus preview policy: ${NAUTILUS_PREVIEW_POLICY:-unset}"
      return "$EXIT_CONFIG_FAILED"
      ;;
  esac
}

gnome_nautilus_plan() {
  cat <<'EOF'
Converge the complete Fedora-native Nautilus stack:
- Nautilus + GVfs core, camera, FUSE, archive, AFC/iPhone, GOA/cloud and NFS backends
- SMB and MTP are enabled only when their declared Golden flags are true
- Sushi quick preview and File Roller Nautilus extension
- explicit thumbnail policy
- true first-click cold-start optimization by prewarming Portal/GIO only, never Nautilus itself
EOF
}

gnome_nautilus_apply() {
  local preview_policy="${NAUTILUS_PREVIEW_POLICY:-local-only}"

  install_manifest_packages GNOME "$REPO_ROOT/manifests/packages-nautilus.txt" || return "$EXIT_APPLY_FAILED"

  if is_true "${NAUTILUS_ENABLE_SMB:-true}"; then
    run_mutating GNOME sudo dnf -y install gvfs-smb || return "$EXIT_APPLY_FAILED"
  fi
  if is_true "${NAUTILUS_ENABLE_MTP:-true}"; then
    run_mutating GNOME sudo dnf -y install gvfs-mtp || return "$EXIT_APPLY_FAILED"
  fi

  if ! is_true "${NAUTILUS_ENABLE_PREVIEWS:-true}"; then
    preview_policy="never"
  fi

  if ! is_true "${DRY_RUN:-true}"; then
    install -d -m 0755 "$HOME/.local/libexec" "$HOME/.config/systemd/user"
    install -m 0755 "$REPO_ROOT/scripts/gnome/nautilus-prewarm.sh" "$HOME/.local/libexec/fedora-gnome-nautilus-prewarm"
    install -m 0644 "$REPO_ROOT/systemd/user/fedora-gnome-nautilus-prewarm.service" "$HOME/.config/systemd/user/fedora-gnome-nautilus-prewarm.service"

    if command_exists gsettings && gsettings list-schemas | grep -Fxq org.gnome.nautilus.preferences; then
      run_mutating GNOME gsettings set org.gnome.nautilus.preferences show-image-thumbnails "'$preview_policy'" || return "$EXIT_APPLY_FAILED"
    fi

    systemctl --user daemon-reload
    systemctl --user enable fedora-gnome-nautilus-prewarm.service
  fi
}

gnome_nautilus_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  "$REPO_ROOT/diagnostics/nautilus-integration-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
}

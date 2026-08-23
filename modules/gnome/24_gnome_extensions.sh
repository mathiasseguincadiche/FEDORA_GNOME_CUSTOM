#!/usr/bin/env bash
set -Eeuo pipefail
gnome_extensions_precheck() { :; }
gnome_extensions_plan() { echo 'Third-party GNOME extensions are opt-in. Extension Manager may be installed from Flathub, but no extension is auto-enabled by default.'; }
gnome_extensions_apply() {
  is_true "${ENABLE_GNOME_EXTENSIONS:-false}" || return 0
  is_true "${ENABLE_FLATHUB:-true}" || return 0
  run_mutating GNOME flatpak install -y flathub com.mattjakeman.ExtensionManager
}
gnome_extensions_postcheck() { :; }

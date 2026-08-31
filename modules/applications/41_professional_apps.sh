#!/usr/bin/env bash
set -Eeuo pipefail

professional_apps_precheck() {
  is_true "${ENABLE_PROFESSIONAL_APPLICATIONS:-true}" || return 0
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/packages-applications-professional-fedora.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/packages-applications-professional-vendor.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/application-provenance.tsv" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/config/repos/vscode.repo" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/config/repos/brave-browser.repo" ]] || return "$EXIT_PRECHECK_FAILED"
  if is_true "${ENABLE_PROFESSIONAL_FLATPAKS:-true}"; then
    command_exists flatpak || return "$EXIT_PRECHECK_FAILED"
    [[ -r "$REPO_ROOT/manifests/flatpaks-applications-professional.txt" ]] || return "$EXIT_PRECHECK_FAILED"
    flatpak remotes --columns=name 2>/dev/null | grep -Fxq flathub || { log_error APPLICATIONS 'Flathub is required for the professional Flatpak profile'; return "$EXIT_PRECHECK_FAILED"; }
  fi
}

professional_apps_plan() { cat <<'EOF'
PROFESSIONAL APPLICATIONS:
- keep GNOME Text Editor as the native GTK4/libadwaita text editor
- install VLC, LibreOffice and FileZilla from Fedora repositories
- install Visual Studio Code from Microsoft's signed RPM repository
- install Brave from Brave Software's signed RPM repository
- install Bitwarden, Slack, ONLYOFFICE, MarkText and draw.io from Flathub
- application provenance/trust class is documented in manifests/application-provenance.tsv
- professional applications are an explicit functional exception to the GTK4-only general desktop rule
EOF
}

professional_apps_apply() {
  local app
  is_true "${ENABLE_PROFESSIONAL_APPLICATIONS:-true}" || return 0
  install_manifest_packages APPLICATIONS "$REPO_ROOT/manifests/packages-applications-professional-fedora.txt" || return "$EXIT_APPLY_FAILED"
  run_mutating APPLICATIONS sudo install -m 0644 "$REPO_ROOT/config/repos/vscode.repo" /etc/yum.repos.d/vscode.repo || return "$EXIT_APPLY_FAILED"
  run_mutating APPLICATIONS sudo install -m 0644 "$REPO_ROOT/config/repos/brave-browser.repo" /etc/yum.repos.d/brave-browser.repo || return "$EXIT_APPLY_FAILED"
  run_mutating APPLICATIONS sudo dnf -y makecache --refresh || return "$EXIT_APPLY_FAILED"
  run_mutating APPLICATIONS sudo dnf -y install "${VSCODE_PACKAGE:-code}" || return "$EXIT_APPLY_FAILED"
  run_mutating APPLICATIONS sudo dnf -y install "${BRAVE_PACKAGE:-brave-browser}" || return "$EXIT_APPLY_FAILED"
  if is_true "${ENABLE_PROFESSIONAL_FLATPAKS:-true}"; then while IFS= read -r app; do [[ -z "$app" || "$app" == \#* ]] && continue; run_mutating APPLICATIONS flatpak install -y flathub "$app" || return "$EXIT_APPLY_FAILED"; done < "$REPO_ROOT/manifests/flatpaks-applications-professional.txt"; fi
}

professional_apps_postcheck() {
  local pkg app
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_PROFESSIONAL_APPLICATIONS:-true}" || return 0
  while IFS= read -r pkg; do [[ -z "$pkg" || "$pkg" == \#* ]] && continue; rpm -q "$pkg" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"; done < "$REPO_ROOT/manifests/packages-applications-professional-fedora.txt"
  rpm -q "${VSCODE_PACKAGE:-code}" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  rpm -q "${BRAVE_PACKAGE:-brave-browser}" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  rpm -q "${TEXT_EDITOR_PACKAGE:-gnome-text-editor}" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  if is_true "${ENABLE_PROFESSIONAL_FLATPAKS:-true}"; then while IFS= read -r app; do [[ -z "$app" || "$app" == \#* ]] && continue; flatpak info "$app" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"; done < "$REPO_ROOT/manifests/flatpaks-applications-professional.txt"; fi
}

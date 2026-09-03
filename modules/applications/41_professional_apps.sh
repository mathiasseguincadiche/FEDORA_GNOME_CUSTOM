#!/usr/bin/env bash
set -Eeuo pipefail

professional_apps_unverified_allowed() {
  local id="$1"
  [[ " ${UNVERIFIED_FLATHUB_ALLOWLIST:-} " == *" $id "* ]]
}

professional_apps_validate_provenance() {
  local provenance="$REPO_ROOT/manifests/application-provenance.tsv"
  local flatpaks="$REPO_ROOT/manifests/flatpaks-applications-professional.txt"
  local id delivery trust note allowed

  while IFS=$'\t' read -r id delivery trust note; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    if [[ "$delivery" == flathub && "$trust" == community-unverified ]]; then
      professional_apps_unverified_allowed "$id" || {
        log_error APPLICATIONS "community-unverified Flathub app is not explicitly allowlisted: $id"
        return "$EXIT_CONFIG_FAILED"
      }
    fi
  done < "$provenance"

  while IFS= read -r id; do
    [[ -z "$id" || "$id" == \#* ]] && continue
    awk -F '\t' -v wanted="$id" '$1 == wanted {found=1} END {exit !found}' "$provenance" || {
      log_error APPLICATIONS "missing application provenance entry: $id"
      return "$EXIT_CONFIG_FAILED"
    }
  done < "$flatpaks"

  for allowed in ${UNVERIFIED_FLATHUB_ALLOWLIST:-}; do
    awk -F '\t' -v wanted="$allowed" '$1 == wanted && $2 == "flathub" && $3 == "community-unverified" {found=1} END {exit !found}' "$provenance" || {
      log_error APPLICATIONS "allowlist entry is not a documented community-unverified Flathub package: $allowed"
      return "$EXIT_CONFIG_FAILED"
    }
  done
}

professional_apps_precheck() {
  is_true "${ENABLE_PROFESSIONAL_APPLICATIONS:-true}" || return 0
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/packages-applications-professional-fedora.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/packages-applications-professional-vendor.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/application-provenance.tsv" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/config/repos/vscode.repo" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/config/repos/brave-browser.repo" ]] || return "$EXIT_PRECHECK_FAILED"
  professional_apps_validate_provenance || return $?
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
- community-unverified Flathub packages require an explicit versioned allowlist entry
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
  professional_apps_validate_provenance || return "$EXIT_POSTCHECK_FAILED"
  while IFS= read -r pkg; do [[ -z "$pkg" || "$pkg" == \#* ]] && continue; rpm -q "$pkg" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"; done < "$REPO_ROOT/manifests/packages-applications-professional-fedora.txt"
  rpm -q "${VSCODE_PACKAGE:-code}" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  rpm -q "${BRAVE_PACKAGE:-brave-browser}" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  rpm -q "${TEXT_EDITOR_PACKAGE:-gnome-text-editor}" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  if is_true "${ENABLE_PROFESSIONAL_FLATPAKS:-true}"; then while IFS= read -r app; do [[ -z "$app" || "$app" == \#* ]] && continue; flatpak info "$app" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"; done < "$REPO_ROOT/manifests/flatpaks-applications-professional.txt"; fi
}

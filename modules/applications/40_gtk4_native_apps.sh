#!/usr/bin/env bash
set -Eeuo pipefail

# Applications GTK4 : installer l'ensemble applicatif GNOME libadwaita ; Ptyxis est le terminal géré ; hors GTK4, seules les exceptions professionnelles et virtualisation sont admises.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).

applications_gtk4_precheck() {
  command_exists dnf
  [[ -r "$REPO_ROOT/manifests/packages-applications-gtk4.txt" ]]
}

applications_gtk4_plan() {
  echo 'Install the curated GNOME GTK4/libadwaita desktop application set. Ptyxis is the managed terminal. Non-GTK4 applications are accepted only through the explicit professional or virtualization exception scopes.'
}

applications_gtk4_apply() {
  install_manifest_packages APPLICATIONS "$REPO_ROOT/manifests/packages-applications-gtk4.txt"
}

applications_gtk4_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  local pkg
  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    rpm -q "$pkg" >/dev/null 2>&1 || return "$EXIT_POSTCHECK_FAILED"
  done < "$REPO_ROOT/manifests/packages-applications-gtk4.txt"
  command_exists "${TERMINAL_PACKAGE:-ptyxis}" || return "$EXIT_POSTCHECK_FAILED"
}

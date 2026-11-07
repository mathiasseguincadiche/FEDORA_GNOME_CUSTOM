#!/usr/bin/env bash
set -Eeuo pipefail

# Validation du domaine applications : GTK4/libadwaita, provenance RPM et Flatpak professionnelles, démarrage réel, AppImage, intégration Nautilus/Ptyxis et associations GNOME par défaut.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).

applications_validation_precheck() {
  [[ -r "$REPO_ROOT/manifests/packages-applications-gtk4.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/packages-applications-professional-fedora.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/packages-applications-professional-vendor.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/flatpaks-applications-professional.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/application-runtime-contract.tsv" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/packages-appimage.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -r "$REPO_ROOT/manifests/flatpaks-appimage.txt" ]] || return "$EXIT_PRECHECK_FAILED"
  [[ -x "$REPO_ROOT/scripts/gnome/configure-default-apps.sh" ]] || return "$EXIT_PRECHECK_FAILED"
}

applications_validation_plan() {
  echo 'Validate GTK4/libadwaita apps, professional RPM/Flatpak provenance and actual runtime startup, AppImage compatibility, Nautilus/Ptyxis integration, and deterministic GNOME default application associations.'
}

applications_validation_apply() {
  is_true "${GNOME_DEFAULT_APPS_ENABLED:-true}" || return 0
  is_true "${DRY_RUN:-true}" && { log_info APPLICATIONS 'DRY-RUN: configure GNOME default application associations'; return 0; }
  "$REPO_ROOT/scripts/gnome/configure-default-apps.sh" full || return "$EXIT_APPLY_FAILED"
}

applications_validation_missing() {
  local kind="$1" identifier="$2" origin="$3"
  ui_check KO "Applications : $kind" "élément manquant : $identifier (source : $origin) ; vérifier l'installation avant de relancer"
  return "$EXIT_POSTCHECK_FAILED"
}

applications_validation_require_doctor() {
  local label="$1" command="$2" rc=0
  shift 2
  "$command" "$@" || rc=$?
  if ((rc != 0)); then
    ui_check KO "Applications : $label" "diagnostic échoué (rc=$rc) ; relancer ./${command#"$REPO_ROOT/"} sans --quiet"
    return "$EXIT_POSTCHECK_FAILED"
  fi
}

applications_validation_postcheck() {
  local pkg app manifest
  is_true "${DRY_RUN:-true}" && return 0

  for manifest in \
    "$REPO_ROOT/manifests/packages-applications-gtk4.txt" \
    "$REPO_ROOT/manifests/packages-applications-professional-fedora.txt" \
    "$REPO_ROOT/manifests/packages-applications-professional-vendor.txt" \
    "$REPO_ROOT/manifests/packages-appimage.txt"; do
    while IFS= read -r pkg; do
      [[ -z "$pkg" || "$pkg" == \#* ]] && continue
      rpm -q "$pkg" >/dev/null 2>&1 || applications_validation_missing RPM "$pkg" "${manifest#"$REPO_ROOT/"}" || return "$EXIT_POSTCHECK_FAILED"
    done < "$manifest"
  done

  rpm -q "${TERMINAL_PACKAGE:-ptyxis}" >/dev/null 2>&1 || applications_validation_missing RPM "${TERMINAL_PACKAGE:-ptyxis}" 'config/applications.conf' || return "$EXIT_POSTCHECK_FAILED"
  rpm -q "${TEXT_EDITOR_PACKAGE:-gnome-text-editor}" >/dev/null 2>&1 || applications_validation_missing RPM "${TEXT_EDITOR_PACKAGE:-gnome-text-editor}" 'config/applications.conf' || return "$EXIT_POSTCHECK_FAILED"
  applications_validation_require_doctor Ptyxis "$REPO_ROOT/diagnostics/ptyxis-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
  applications_validation_require_doctor 'Intégration Ptyxis' "$REPO_ROOT/diagnostics/ptyxis-integration-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
  applications_validation_require_doctor 'Nautilus et Ptyxis' "$REPO_ROOT/diagnostics/nautilus-ptyxis-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
  applications_validation_require_doctor 'Applications par défaut' "$REPO_ROOT/diagnostics/default-apps-doctor" --quiet --full || return "$EXIT_POSTCHECK_FAILED"
  applications_validation_require_doctor AppImage "$REPO_ROOT/diagnostics/appimage-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
  applications_validation_require_doctor 'Démarrage des applications' "$REPO_ROOT/diagnostics/application-runtime-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"

  if is_true "${ENABLE_PROFESSIONAL_FLATPAKS:-true}"; then
    for manifest in \
      "$REPO_ROOT/manifests/flatpaks-applications-professional.txt" \
      "$REPO_ROOT/manifests/flatpaks-appimage.txt"; do
      while IFS= read -r app; do
        [[ -z "$app" || "$app" == \#* ]] && continue
        flatpak info "$app" >/dev/null 2>&1 || applications_validation_missing Flatpak "$app" "${manifest#"$REPO_ROOT/"}" || return "$EXIT_POSTCHECK_FAILED"
      done < "$manifest"
    done
  fi
}

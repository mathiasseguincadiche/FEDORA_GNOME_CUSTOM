#!/usr/bin/env bash
set -Eeuo pipefail

# RPM Fusion pour les paquets multimédia et jeu explicitement approuvés, Flathub pour les applications du bureau ; jamais de dépôt de pilote GPU.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).
system_sources_precheck() { command_exists dnf; }
system_sources_plan() { echo 'Enable RPM Fusion only for explicitly approved multimedia and gaming packages and Flathub for curated desktop apps; never add GPU driver repositories.'; }
system_sources_apply() {
  if is_true "${ENABLE_RPMFUSION:-true}"; then
    local fedora; fedora="$(rpm -E %fedora)"
    local channel
    for channel in free nonfree; do
      run_mutating SYSTEM sudo bash "$REPO_ROOT/scripts/packages/install-rpmfusion-release.sh" "$fedora" "$channel" \
        "https://mirrors.rpmfusion.org/${channel}/fedora/rpmfusion-${channel}-release-${fedora}.noarch.rpm" \
        "https://download1.rpmfusion.org/${channel}/fedora/rpmfusion-${channel}-release-${fedora}.noarch.rpm" \
        || return "$EXIT_APPLY_FAILED"
    done
  fi
  if is_true "${ENABLE_FLATHUB:-true}"; then
    run_mutating SYSTEM sudo dnf -y install flatpak
    run_mutating SYSTEM flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
}
system_sources_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  if is_true "${ALLOW_THIRD_PARTY_GPU_REPOS:-false}"; then return 0; fi
  ! dnf repolist --all | grep -Eqi 'intel.*gpu|graphics.*driver|mesa-git|copr.*mesa' || { log_error SYSTEM 'unexpected third-party GPU repository detected'; return "$EXIT_POSTCHECK_FAILED"; }
}

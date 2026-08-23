#!/usr/bin/env bash
set -Eeuo pipefail
system_sources_precheck() { command_exists dnf; }
system_sources_plan() { echo 'Enable RPM Fusion only for explicitly requested multimedia packages and Flathub for curated desktop apps; never add GPU driver repositories.'; }
system_sources_apply() {
  if is_true "${ENABLE_RPMFUSION:-true}"; then
    local fedora; fedora="$(rpm -E %fedora)"
    run_mutating SYSTEM sudo dnf -y install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora}.noarch.rpm" "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedora}.noarch.rpm"
  fi
  if is_true "${ENABLE_FLATHUB:-true}"; then
    run_mutating SYSTEM sudo dnf -y install flatpak
    run_mutating SYSTEM flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi
}
system_sources_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  if is_true "${ALLOW_THIRD_PARTY_GPU_REPOS:-false}"; then return 0; fi
  ! dnf repolist --all | grep -Eqi 'intel.*gpu|graphics.*driver|mesa-git|copr.*mesa' || { log_error SYSTEM 'unexpected third-party GPU repository detected'; return "$EXIT_POSTCHECK_FAILED"; }
}

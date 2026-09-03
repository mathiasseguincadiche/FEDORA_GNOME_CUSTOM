#!/usr/bin/env bash
set -Eeuo pipefail

gaming_stack_enabled() { is_true "${GAMING_ENABLE:-false}"; }

gaming_stack_precheck() {
  gaming_stack_enabled || return 0
  command_exists dnf || { log_error GAMING 'dnf is required'; return "$EXIT_PRECHECK_FAILED"; }
  [[ "$(uname -m)" == x86_64 ]] || { log_error GAMING 'Steam Golden profile requires x86_64'; return "$EXIT_PRECHECK_FAILED"; }
  is_true "${ENABLE_RPMFUSION:-true}" || { log_error GAMING 'GAMING_ENABLE=true requires ENABLE_RPMFUSION=true for the Steam RPM'; return "$EXIT_PRECHECK_FAILED"; }
}

gaming_stack_plan() {
  if gaming_stack_enabled; then
    echo 'Install Fedora-native Vulkan multilib, GameMode, MangoHud, GOverlay, Gamescope and Steam Input; install Steam from RPM Fusion nonfree Steam without custom Mesa/kernel repositories or global performance tweaks. Proton remains Steam-managed.'
  else
    echo 'Gaming profile disabled; preserve the Golden HOST without gaming packages.'
  fi
}

gaming_stack_apply() {
  local pkg repo_payload
  gaming_stack_enabled || return 0

  install_manifest_packages GAMING "$REPO_ROOT/manifests/packages-gaming.txt" || return "$EXIT_APPLY_FAILED"

  if ! is_true "${DRY_RUN:-true}"; then
    repo_payload="$(dnf repolist --all 2>/dev/null || true)"
    grep -Fq 'rpmfusion-nonfree-steam' <<<"$repo_payload" || {
      log_error GAMING 'rpmfusion-nonfree-steam repository is unavailable after RPM Fusion setup'
      return "$EXIT_APPLY_FAILED"
    }
  fi

  while IFS= read -r pkg; do
    [[ -z "$pkg" || "$pkg" == \#* ]] && continue
    run_mutating GAMING sudo dnf -y --enablerepo=rpmfusion-nonfree-steam install "$pkg" || return "$EXIT_APPLY_FAILED"
  done < "$REPO_ROOT/manifests/packages-gaming-rpmfusion.txt"
}

gaming_stack_postcheck() {
  local steam_bin
  gaming_stack_enabled || return 0
  is_true "${DRY_RUN:-true}" && return 0

  rpm -q steam gamemode gamescope mangohud goverlay steam-devices vulkan-tools >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  rpm -q mesa-vulkan-drivers.x86_64 mesa-vulkan-drivers.i686 mesa-dri-drivers.x86_64 mesa-dri-drivers.i686 vulkan-loader.x86_64 vulkan-loader.i686 >/dev/null || return "$EXIT_POSTCHECK_FAILED"

  command_exists steam || return "$EXIT_POSTCHECK_FAILED"
  command_exists gamemoderun || return "$EXIT_POSTCHECK_FAILED"
  command_exists mangohud || return "$EXIT_POSTCHECK_FAILED"
  command_exists gamescope || return "$EXIT_POSTCHECK_FAILED"
  command_exists vulkaninfo || return "$EXIT_POSTCHECK_FAILED"
  steam_bin="$(command -v steam)"
  rpm -qf "$steam_bin" >/dev/null || return "$EXIT_POSTCHECK_FAILED"
}

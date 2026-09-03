#!/usr/bin/env bash
set -Eeuo pipefail
gnome_core_precheck() { command_exists dnf; }
gnome_core_plan() { echo 'Install/validate Fedora GNOME core, portals and Flatpak while preserving Fedora GNOME defaults for compositor/font rendering. Nautilus integration is converged by the dedicated gnome.nautilus module.'; }
gnome_core_apply() { install_manifest_packages GNOME "$REPO_ROOT/manifests/packages-gnome.txt"; }
gnome_core_postcheck() { is_true "${DRY_RUN:-true}" && return 0; rpm -q gnome-shell mutter gnome-control-center xdg-desktop-portal-gnome >/dev/null; }

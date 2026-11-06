#!/usr/bin/env bash
set -Eeuo pipefail

# Crochet de capture de la mise en veille, en lecture seule : état du noyau, de xe/DRM, de PCIe et des connecteurs avant/après ; jamais de changement automatique du mode de veille.
# Contrat de module : precheck, plan, apply, postcheck (docs/ARCHITECTURE.md, section « Contrat d'exécution »).
hardware_suspend_precheck() { [[ -r "$REPO_ROOT/scripts/systemd/fedora-custom-sleep-hook" ]]; }
hardware_suspend_plan() { echo 'Install a read-only system-sleep capture hook. It records pre/post kernel, xe/DRM, PCIe and display connector state; it never changes sleep mode automatically.'; }
hardware_suspend_apply() {
  run_mutating HARDWARE sudo install -D -m 0755 "$REPO_ROOT/scripts/systemd/fedora-custom-sleep-hook" /usr/lib/systemd/system-sleep/fedora-gnome-custom
  run_mutating HARDWARE sudo install -d -m 0755 /var/lib/fedora-gnome-custom/suspend
}
hardware_suspend_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  [[ -x /usr/lib/systemd/system-sleep/fedora-gnome-custom ]] || return "$EXIT_POSTCHECK_FAILED"
  if [[ -r /sys/power/mem_sleep ]]; then log_info HARDWARE "mem_sleep=$(cat /sys/power/mem_sleep)"; fi
}

#!/usr/bin/env bash
# Rolling N/N-1 kernel operator surface. Loaded after the base Control Center so
# these two functions replace the historical candidate/Fedora-fallback wording.

cc_show_kernel_inventory() {
  printf 'Kernel actif : %s\n\n' "$(uname -r)"
  if command_exists rpm; then
    rpm -q --qf 'kernel-core\t%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null | sort -V || true
  else
    printf 'rpm indisponible dans cet environnement.\n'
  fi
  printf '\nPolitique versionnée :\n'
  printf '  Source             kernel-vanilla/stable\n'
  printf '  Cible              latest stable direct\n'
  printf '  Minimum actuel     %s\n' "${KERNEL_MIN_VERSION:-non défini}"
  printf '  Rétention          N / N-1, maximum 2\n'
  printf '  Fedora fallback    non permanent (recovery explicite)\n'
}

cc_kernel_menu() {
  local choice=''
  while true; do
    cc_clear
    cc_header
    cc_section '5 — KERNEL & BOOT'
    cc_option 1 'Inventaire kernels' 'N + N-1 + défaut GRUB'
    cc_option 2 'Kernel doctor' 'rolling N/N-1'
    cc_option 3 'Vérifier mises à jour kernel' 'via update check'
    cc_option 4 'Installer dernier stable' 'direct, N devient défaut'
    cc_option 5 'Rollback vers N-1' 'conserve N installé'
    cc_option 6 'Appliquer rétention kernel' 'maximum 2 versions'
    cc_option 7 'Recovery vers kernel Fedora' 'urgence uniquement'
    cc_option 8 'Collecter panne de boot'
    cc_option 0 'Retour'
    read -r -p 'Choix : ' choice
    case "$choice" in
      1) cc_interactive_exec 'INVENTAIRE KERNEL N / N-1' cc_show_kernel_inventory ;;
      2) cc_interactive_exec 'KERNEL DOCTOR' "$REPO_ROOT/diagnostics/kernel-doctor" ;;
      3) cc_interactive_exec 'RECHERCHE MISES À JOUR KERNEL' "$REPO_ROOT/scripts/maintenance/update-system.sh" --check ;;
      4)
        if cc_confirm 'Installer directement le dernier Kernel Vanilla stable et le définir par défaut ?'; then
          cc_interactive_exec 'INSTALLATION LATEST-STABLE' bash "$REPO_ROOT/scripts/kernel/kernel-lifecycle.sh" install-latest
        fi
        ;;
      5)
        if cc_confirm 'Définir N-1 comme noyau par défaut au prochain démarrage ?'; then
          cc_interactive_exec 'ROLLBACK KERNEL N-1' bash "$REPO_ROOT/scripts/kernel/kernel-lifecycle.sh" rollback
        fi
        ;;
      6)
        if cc_confirm 'Supprimer les kernels plus anciens que N-1 selon la politique max=2 ?'; then
          cc_interactive_exec 'RÉTENTION KERNEL N/N-1' bash "$REPO_ROOT/scripts/kernel/kernel-lifecycle.sh" prune
        fi
        ;;
      7)
        if cc_confirm 'Basculer en récupération vers les paquets kernel Fedora ?'; then
          cc_interactive_exec 'RECOVERY KERNEL FEDORA' "$REPO_ROOT/scripts/kernel/rollback-to-fedora.sh"
        fi
        ;;
      8) cc_interactive_exec 'COLLECTE PANNE DE BOOT' "$REPO_ROOT/scripts/collect-boot-failure.sh" ;;
      0) return 0 ;;
      *) printf 'Choix invalide.\n'; sleep 1 ;;
    esac
  done
}

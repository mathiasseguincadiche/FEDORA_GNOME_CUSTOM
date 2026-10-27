#!/usr/bin/env bash
# Rolling N/N-1 kernel operator surface. Loaded after the base Control Center so
# these two functions replace the historical candidate/Fedora-fallback wording.

cc_show_kernel_inventory() {
  printf 'Kernel actif : %s\n\n' "$(uname -r)"
  if command_exists rpm; then
    rpm -q --qf '%{NAME}\t%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null | grep -v 'is not installed' | sort -V || true
  else
    printf 'rpm indisponible dans cet environnement.\n'
  fi
  printf '\nPolitique versionnée :\n'
  printf '  Canal              %s (%s)\n' "${KERNEL_CHANNEL:-vanilla}" "$(kernel_channel_copr 2>/dev/null || echo 'non résolu')"
  printf '  Cible              latest stable direct\n'
  printf '  Minimum actuel     %s\n' "${KERNEL_MIN_VERSION:-non défini}"
  printf '  Rétention          N / N-1 amont, maximum 2 kernel-core\n'
  printf '  Secours            N-1 + noyau Fedora signé %s (jamais par défaut)\n' "$(kernel_lifecycle_fedora_fallback 2>/dev/null || true)"
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
    cc_option 6 'Appliquer rétention kernel' 'N/N-1 amont + secours Fedora'
    cc_option 7 'Démarrer sur le secours Fedora' 'défaut GRUB, sans rien supprimer'
    cc_option 8 'Rafraîchir le secours Fedora' 'dernier noyau Fedora signé'
    cc_option 9 'Recovery vers kernel Fedora' 'urgence : quitte le canal amont'
    cc_option 10 'Collecter panne de boot'
    cc_option 0 'Retour'
    read -r -p 'Choix : ' choice
    case "$choice" in
      1) cc_interactive_exec 'INVENTAIRE KERNEL N / N-1' cc_show_kernel_inventory ;;
      2) cc_interactive_exec 'KERNEL DOCTOR' "$REPO_ROOT/diagnostics/kernel-doctor" ;;
      3) cc_interactive_exec 'RECHERCHE MISES À JOUR KERNEL' "$REPO_ROOT/scripts/maintenance/update-system.sh" --check ;;
      4)
        if cc_confirm "Installer le dernier noyau stable du canal ${KERNEL_CHANNEL:-vanilla} et le définir par défaut ?"; then
          cc_interactive_exec 'INSTALLATION LATEST-STABLE' bash "$REPO_ROOT/scripts/kernel/kernel-lifecycle.sh" install-latest
        fi
        ;;
      5)
        if cc_confirm 'Définir N-1 comme noyau par défaut au prochain démarrage ?'; then
          cc_interactive_exec 'ROLLBACK KERNEL N-1' bash "$REPO_ROOT/scripts/kernel/kernel-lifecycle.sh" rollback
        fi
        ;;
      6)
        if cc_confirm 'Supprimer les kernels amont plus anciens que N-1 (le secours Fedora est conservé) ?'; then
          cc_interactive_exec 'RÉTENTION KERNEL N/N-1' bash "$REPO_ROOT/scripts/kernel/kernel-lifecycle.sh" prune
        fi
        ;;
      7)
        if cc_confirm 'Définir le noyau Fedora de secours comme défaut au prochain démarrage ?'; then
          cc_interactive_exec 'SECOURS KERNEL FEDORA' bash "$REPO_ROOT/scripts/kernel/kernel-lifecycle.sh" fallback
        fi
        ;;
      8)
        if cc_confirm 'Remplacer le secours par le dernier noyau Fedora signé ?'; then
          cc_interactive_exec 'RAFRAÎCHIR SECOURS FEDORA' bash "$REPO_ROOT/scripts/kernel/kernel-lifecycle.sh" refresh-fallback
        fi
        ;;
      9)
        if cc_confirm 'Basculer en récupération vers les paquets kernel Fedora ?'; then
          cc_interactive_exec 'RECOVERY KERNEL FEDORA' "$REPO_ROOT/scripts/kernel/rollback-to-fedora.sh"
        fi
        ;;
      10) cc_interactive_exec 'COLLECTE PANNE DE BOOT' "$REPO_ROOT/scripts/collect-boot-failure.sh" ;;
      0) return 0 ;;
      *) printf 'Choix invalide.\n'; sleep 1 ;;
    esac
  done
}

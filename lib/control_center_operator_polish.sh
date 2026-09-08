#!/usr/bin/env bash
# Small operator-surface overlay. Business logic stays in dedicated scripts.

cc_update_menu() {
  local choice=''
  while true; do
    cc_clear
    cc_header
    cc_section '2 — MISES À JOUR'
    cc_option 1 'Vérifier les mises à jour' 'Fedora + Flatpak + firmware'
    cc_option 2 'Préparer mise à jour complète' 'backup → DNF5 offline'
    cc_option 3 'Préparer Fedora seulement' 'backup → DNF5 offline'
    cc_option 4 'Redémarrer en transaction offline' 'état préparé obligatoire'
    cc_option 5 'Finaliser après redémarrage' 'DNF check → Flatpak → doctor'
    cc_option 6 'Mise à jour Flatpak seulement'
    cc_option 7 'Firmware disponible' 'consultation uniquement'
    cc_option 8 'État transaction offline'
    cc_option 9 'Dernier journal DNF5 offline'
    cc_option 0 'Retour'
    read -r -p 'Choix : ' choice
    case "$choice" in
      1) cc_interactive_exec 'VÉRIFICATION DES MISES À JOUR' "$REPO_ROOT/scripts/maintenance/update-system.sh" --check ;;
      2)
        if cc_confirm 'Créer un backup puis préparer la mise à jour complète ?'; then
          cc_interactive_exec 'PRÉPARATION MISE À JOUR COMPLÈTE' "$REPO_ROOT/scripts/maintenance/update-system.sh" --apply
        fi
        ;;
      3)
        if cc_confirm 'Créer un backup puis préparer la mise à jour Fedora ?'; then
          cc_interactive_exec 'PRÉPARATION MISE À JOUR FEDORA' "$REPO_ROOT/scripts/maintenance/update-system.sh" --dnf-only
        fi
        ;;
      4)
        if cc_confirm 'Redémarrer maintenant dans la transaction DNF5 offline préparée ?'; then
          cc_interactive_exec 'REDÉMARRAGE DNF5 OFFLINE' "$REPO_ROOT/scripts/maintenance/update-system.sh" --offline-reboot
        fi
        ;;
      5) cc_interactive_exec 'FINALISATION POST-OFFLINE' "$REPO_ROOT/scripts/maintenance/update-system.sh" --finalize ;;
      6) cc_interactive_exec 'MISE À JOUR FLATPAK' "$REPO_ROOT/scripts/maintenance/update-system.sh" --flatpak-only ;;
      7) cc_interactive_exec 'FIRMWARE DISPONIBLE — AUCUN FLASH' "$REPO_ROOT/scripts/maintenance/update-system.sh" --firmware-check ;;
      8) cc_interactive_exec 'ÉTAT DNF5 OFFLINE' "$REPO_ROOT/scripts/maintenance/update-system.sh" --offline-status ;;
      9) cc_interactive_exec 'JOURNAL DNF5 OFFLINE' "$REPO_ROOT/scripts/maintenance/update-system.sh" --offline-log ;;
      0) return 0 ;;
      *) printf 'Choix invalide.\n'; sleep 1 ;;
    esac
  done
}

cc_logs_menu() {
  local choice=''
  while true; do
    cc_clear
    cc_header
    cc_section '9 — LOGS & PREUVES'
    cc_option 1 'Lister logs / rapports / markers'
    cc_option 2 'Afficher dernier main.log'
    cc_option 3 'Collecter panne de boot'
    cc_option 4 'Afficher commit courant'
    cc_option 5 'Prévisualiser rétention' 'aucune suppression'
    cc_option 6 'Appliquer rétention' 'preuves référencées protégées'
    cc_option 0 'Retour'
    read -r -p 'Choix : ' choice
    case "$choice" in
      1) cc_interactive_exec 'LOGS & PREUVES' cc_show_logs ;;
      2) cc_interactive_exec 'DERNIER MAIN.LOG' cc_tail_latest_log ;;
      3) cc_interactive_exec 'COLLECTE PANNE DE BOOT' "$REPO_ROOT/scripts/collect-boot-failure.sh" ;;
      4) cc_interactive_exec 'SOURCE DE VÉRITÉ GIT' cc_show_git_source ;;
      5) cc_interactive_exec 'RÉTENTION — DRY RUN' bash "$REPO_ROOT/scripts/maintenance/prune-project-evidence.sh" --dry-run ;;
      6)
        if cc_confirm 'Supprimer uniquement les vieux logs/rapports non référencés selon la politique versionnée ?'; then
          cc_interactive_exec 'RÉTENTION — APPLY' bash "$REPO_ROOT/scripts/maintenance/prune-project-evidence.sh" --apply
        fi
        ;;
      0) return 0 ;;
      *) printf 'Choix invalide.\n'; sleep 1 ;;
    esac
  done
}

#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while true; do
  cat <<'EOF'

FEDORA GNOME CUSTOM — GOLDEN WORKSTATION
1) Diagnostic global
2) Hardware baseline status
3) Hardware baseline snapshot
4) Tester RAM 5600 automatiquement
5) Tester RAM 6000 automatiquement
6) Tester T705 système automatiquement
7) Tester T705 /data automatiquement
8) Certifier baseline pré-APPLY
9) Dry-run complet
10) Préparer backup pré-APPLY
11) APPLY réel protégé
12) Kernel doctor
13) Display doctor
14) Réparer affichage maintenant
15) Mesurer cold-start Nautilus
16) Suspend/resume doctor
17) Enregistrer cycle suspend post-APPLY
18) Statut certification finale
19) Certifier Golden Workstation
20) Graphics doctor
21) Storage doctor
22) GNOME doctor
23) Applications doctor
24) Multimedia / codecs doctor
25) Virtualization / KVM doctor
26) Configurer / rafraîchir accès Nautilus aux VM
27) Backup / recovery doctor
28) Backup complet HOST + métadonnées KVM
29) Backup complet + disques VM arrêtées
30) Lister snapshots Restic
31) Vérifier profondément repository Restic
32) Générer plan Disaster Recovery
33) Restaurer snapshot vers staging
34) Rollback vers noyau Fedora
0) Quitter
EOF
  read -rp 'Choix: ' choice
  case "$choice" in
    1) "$REPO_ROOT/diagnostic.sh" ;;
    2) "$REPO_ROOT/diagnostics/baseline-doctor" status ;;
    3) "$REPO_ROOT/diagnostics/baseline-doctor" snapshot ;;
    4) "$REPO_ROOT/diagnostics/baseline-doctor" run-memory-test 5600 ;;
    5) "$REPO_ROOT/diagnostics/baseline-doctor" run-memory-test 6000 ;;
    6) "$REPO_ROOT/diagnostics/baseline-doctor" run-nvme-test root ;;
    7) "$REPO_ROOT/diagnostics/baseline-doctor" run-nvme-test data ;;
    8) "$REPO_ROOT/diagnostics/baseline-doctor" certify ;;
    9) "$REPO_ROOT/install.sh" --dry-run ;;
    10) "$REPO_ROOT/prepare-preapply-backup.sh" ;;
    11) "$REPO_ROOT/install.sh" --apply ;;
    12) "$REPO_ROOT/diagnostics/kernel-doctor" ;;
    13) "$REPO_ROOT/diagnostics/display-doctor" ;;
    14) "$HOME/.local/libexec/fedora-gnome-display-repair" ;;
    15) "$REPO_ROOT/diagnostics/nautilus-coldstart-doctor" ;;
    16) "$REPO_ROOT/diagnostics/suspend-doctor" ;;
    17) "$REPO_ROOT/diagnostics/final-certification" record-suspend ;;
    18) "$REPO_ROOT/diagnostics/final-certification" status ;;
    19) "$REPO_ROOT/diagnostics/final-certification" certify ;;
    20) "$REPO_ROOT/diagnostics/graphics-doctor" ;;
    21) "$REPO_ROOT/diagnostics/storage-doctor" ;;
    22) "$REPO_ROOT/diagnostics/gnome-doctor" ;;
    23) "$REPO_ROOT/diagnostics/applications-doctor" ;;
    24) "$REPO_ROOT/diagnostics/media-doctor" ;;
    25) "$REPO_ROOT/diagnostics/virtualization-doctor" ;;
    26) "$REPO_ROOT/scripts/kvm/configure_nautilus_vm_access.sh" refresh ;;
    27) "$REPO_ROOT/diagnostics/backup-doctor" ;;
    28) "$REPO_ROOT/scripts/backup/backup-now.sh" ;;
    29) "$REPO_ROOT/scripts/backup/backup-now.sh" --include-vms ;;
    30) "$REPO_ROOT/scripts/backup/restore.sh" list ;;
    31) "$REPO_ROOT/diagnostics/backup-doctor" --deep ;;
    32) "$REPO_ROOT/scripts/backup/disaster-recovery.sh" ;;
    33) read -rp 'Snapshot [latest]: ' snap; "$REPO_ROOT/scripts/backup/restore.sh" restore "${snap:-latest}" ;;
    34) "$REPO_ROOT/scripts/kernel/rollback-to-fedora.sh" ;;
    0) exit 0 ;;
    *) echo 'Choix invalide.' ;;
  esac
done

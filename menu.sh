#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while true; do
  cat <<'EOF'

FEDORA GNOME CUSTOM
1) Diagnostic global
2) Hardware baseline status
3) Hardware baseline snapshot
4) Dry-run complet
5) Préparer backup pré-APPLY
6) APPLY réel protégé
7) Graphics doctor
8) Suspend/resume doctor
9) Storage doctor
10) GNOME doctor
11) Applications doctor
12) Multimedia / codecs doctor
13) Virtualization / KVM doctor
14) Créer Ubuntu Server 26.04 DevOps
15) Créer Windows 11
16) Certification runtime KVM
17) Configurer / rafraîchir accès Nautilus aux VM
18) Ouvrir Ubuntu DevOps dans Nautilus
19) Ouvrir Windows VM dans Nautilus
20) Backup / recovery doctor
21) Backup complet HOST + métadonnées KVM
22) Backup complet + disques VM arrêtées
23) Lister les snapshots Restic
24) Vérifier profondément le repository Restic
25) Générer le plan Disaster Recovery
26) Restaurer un snapshot vers staging
27) Kernel / microcode / AMD P-State doctor
28) Topologie MSI B850M / PCIe / ReBAR doctor
29) Power / runtime-PM doctor
30) Pipeline affichage GNOME / Wayland doctor
31) Réseau HOST doctor
32) Audio / PipeWire / ALC4080 doctor
33) Crash forensic doctor
34) Analyse du boot précédent
35) Stress stabilité CPU/RAM (30 min)
36) Certification suspend/resume (10 cycles)
37) Certification workstation finale
0) Quitter
EOF
  read -rp 'Choix: ' choice
  case "$choice" in
    1) "$REPO_ROOT/diagnostic.sh" ;;
    2) bash "$REPO_ROOT/diagnostics/baseline-doctor" status ;;
    3) bash "$REPO_ROOT/diagnostics/baseline-doctor" snapshot ;;
    4) "$REPO_ROOT/install.sh" --dry-run ;;
    5) "$REPO_ROOT/prepare-preapply-backup.sh" ;;
    6) "$REPO_ROOT/install.sh" --apply ;;
    7) "$REPO_ROOT/diagnostics/graphics-doctor" ;;
    8) "$REPO_ROOT/diagnostics/suspend-doctor" ;;
    9) "$REPO_ROOT/diagnostics/storage-doctor" ;;
    10) "$REPO_ROOT/diagnostics/gnome-doctor" ;;
    11) bash "$REPO_ROOT/diagnostics/applications-doctor" ;;
    12) bash "$REPO_ROOT/diagnostics/media-doctor" ;;
    13) bash "$REPO_ROOT/diagnostics/virtualization-doctor" ;;
    14)
      read -rp 'Chemin image cloud Ubuntu Server 26.04: ' image
      read -rp 'Clé SSH publique [~/.ssh/id_ed25519.pub]: ' key
      if [[ -n "$key" ]]; then bash "$REPO_ROOT/scripts/kvm/create_ubuntu_devops_vm.sh" --cloud-image "$image" --ssh-key "$key"; else bash "$REPO_ROOT/scripts/kvm/create_ubuntu_devops_vm.sh" --cloud-image "$image"; fi
      ;;
    15)
      read -rp 'Chemin ISO Windows 11: ' windows_iso
      read -rp 'Chemin ISO virtio-win: ' virtio_iso
      bash "$REPO_ROOT/scripts/kvm/create_windows11_vm.sh" --windows-iso "$windows_iso" --virtio-iso "$virtio_iso"
      ;;
    16) bash "$REPO_ROOT/scripts/kvm/runtime_certification.sh" ;;
    17) bash "$REPO_ROOT/scripts/kvm/configure_nautilus_vm_access.sh" refresh ;;
    18) bash "$REPO_ROOT/scripts/kvm/configure_nautilus_vm_access.sh" open-ubuntu ;;
    19) bash "$REPO_ROOT/scripts/kvm/configure_nautilus_vm_access.sh" open-windows ;;
    20) bash "$REPO_ROOT/diagnostics/backup-doctor" ;;
    21) bash "$REPO_ROOT/scripts/backup/backup-now.sh" ;;
    22) bash "$REPO_ROOT/scripts/backup/backup-now.sh" --include-vms ;;
    23) bash "$REPO_ROOT/scripts/backup/restore.sh" list ;;
    24) bash "$REPO_ROOT/diagnostics/backup-doctor" --deep ;;
    25) bash "$REPO_ROOT/scripts/backup/disaster-recovery.sh" ;;
    26)
      read -rp 'Snapshot [latest]: ' snap
      read -rp 'Répertoire staging vide [défaut automatique]: ' target
      snap="${snap:-latest}"
      if [[ -n "$target" ]]; then bash "$REPO_ROOT/scripts/backup/restore.sh" restore "$snap" "$target"; else bash "$REPO_ROOT/scripts/backup/restore.sh" restore "$snap"; fi
      ;;
    27) bash "$REPO_ROOT/diagnostics/kernel-doctor" ;;
    28) bash "$REPO_ROOT/diagnostics/hardware-topology-doctor" ;;
    29) bash "$REPO_ROOT/diagnostics/power-doctor" ;;
    30) bash "$REPO_ROOT/diagnostics/display-pipeline-doctor" ;;
    31) bash "$REPO_ROOT/diagnostics/network-doctor" ;;
    32) bash "$REPO_ROOT/diagnostics/audio-doctor" ;;
    33) bash "$REPO_ROOT/diagnostics/crash-doctor" ;;
    34) bash "$REPO_ROOT/diagnostics/last-boot-doctor" ;;
    35) bash "$REPO_ROOT/scripts/hardware/stability-stress.sh" --execute --minutes 30 ;;
    36) bash "$REPO_ROOT/scripts/hardware/suspend-certify.sh" --execute --cycles 10 ;;
    37) bash "$REPO_ROOT/scripts/hardware/workstation-certify.sh" ;;
    0) exit 0 ;;
    *) echo 'Choix invalide.' ;;
  esac
done

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
      if [[ -n "$key" ]]; then
        bash "$REPO_ROOT/scripts/kvm/create_ubuntu_devops_vm.sh" --cloud-image "$image" --ssh-key "$key"
      else
        bash "$REPO_ROOT/scripts/kvm/create_ubuntu_devops_vm.sh" --cloud-image "$image"
      fi
      ;;
    15)
      read -rp 'Chemin ISO Windows 11: ' windows_iso
      read -rp 'Chemin ISO virtio-win: ' virtio_iso
      bash "$REPO_ROOT/scripts/kvm/create_windows11_vm.sh" --windows-iso "$windows_iso" --virtio-iso "$virtio_iso"
      ;;
    16) bash "$REPO_ROOT/scripts/kvm/runtime_certification.sh" ;;
    0) exit 0 ;;
    *) echo 'Choix invalide.' ;;
  esac
done

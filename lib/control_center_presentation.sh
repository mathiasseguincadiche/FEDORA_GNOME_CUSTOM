#!/usr/bin/env bash
# Presentation layer loaded after the base Control Center and kernel rolling UI.
# It only refines operator-facing wording/status; business logic remains in the
# dedicated diagnostics and scripts.

cc_data_state() {
  local mount="${KVM_DATA_MOUNT:-/data}"
  local fstype=''
  if ! runtime_is_baremetal; then
    printf 'EXPECTED'
    return 0
  fi
  if ! command_exists findmnt; then
    printf 'UNKNOWN'
    return 0
  fi
  fstype="$(findmnt -rn -T "$mount" -o FSTYPE 2>/dev/null | head -n 1 || true)"
  if [[ "$fstype" == ext4 ]]; then
    printf 'PASS'
  else
    printf 'WARN'
  fi
}

cc_data_detail() {
  local mount="${KVM_DATA_MOUNT:-/data}"
  if ! runtime_is_baremetal; then
    printf '%s' "$mount différé"
    return 0
  fi
  if command_exists findmnt && [[ "$(findmnt -rn -T "$mount" -o FSTYPE 2>/dev/null | head -n 1 || true)" == ext4 ]]; then
    printf '%s' "$mount EXT4"
  else
    printf '%s' "$mount à vérifier"
  fi
}

cc_gaming_state() {
  if ! is_true "${GAMING_ENABLE:-false}"; then
    printf 'KO'
    return 0
  fi
  if ! runtime_is_baremetal; then
    printf 'EXPECTED'
    return 0
  fi
  if command_exists steam && command_exists vulkaninfo; then
    printf 'PASS'
  else
    printf 'WARN'
  fi
}

cc_gaming_detail() {
  if ! is_true "${GAMING_ENABLE:-false}"; then
    printf 'profil désactivé'
  elif ! runtime_is_baremetal; then
    printf 'preuve différée'
  else
    printf 'Steam / Vulkan'
  fi
}

cc_header() {
  local version fedora runtime kernel sha gpu
  local git_state backup_state backup_detail cert_state kvm_state reboot_state
  local data_state data_detail gaming_state gaming_detail

  version="$(cc_version)"
  fedora="$(cc_fedora_version)"
  runtime="${RUNTIME_ENVIRONMENT^^}"
  kernel="$(uname -r 2>/dev/null || printf unknown)"
  sha="$(cc_project_sha)"
  gpu="$(cc_gpu_detail)"
  git_state="$(cc_git_state)"
  backup_state="$(cc_backup_state)"
  backup_detail="$(cc_backup_detail)"
  cert_state="$(cc_cert_state)"
  kvm_state="$(cc_kvm_state)"
  reboot_state="$(cc_reboot_state)"
  data_state="$(cc_data_state)"
  data_detail="$(cc_data_detail)"
  gaming_state="$(cc_gaming_state)"
  gaming_detail="$(cc_gaming_detail)"

  printf '%s%s' "$CC_BLUE" "$CC_BOLD"
  cc_double_rule
  printf '%s' "$CC_RESET"
  printf '%s%s  FEDORA GOLDEN WORKSTATION — CENTRE DE CONTRÔLE%s\n' "$CC_BOLD" "$CC_CYAN" "$CC_RESET"
  printf '%s' "$CC_BLUE"
  cc_double_rule
  printf '%s' "$CC_RESET"
  printf '  Projet      %-10s  SHA %-10s  Fedora %-6s  Runtime %-10s\n' "$version" "$sha" "$fedora" "$runtime"
  printf '  Kernel      %-32s Politique N / N-1 · max 2\n' "$kernel"
  printf '  GPU         %-32s Git      ' "$gpu"
  cc_badge "$git_state"
  printf '\n'
  printf '  Data        '
  cc_badge "$data_state"
  printf ' %-24s Gaming   ' "$data_detail"
  cc_badge "$gaming_state"
  printf ' %s\n' "$gaming_detail"
  printf '  Backup      '
  cc_badge "$backup_state"
  printf ' %-24s Certif.  ' "$backup_detail"
  cc_badge "$cert_state"
  printf '\n'
  printf '  KVM         '
  cc_badge "$kvm_state"
  printf ' %-24s Reboot   ' "${KVM_NETWORK_NAME:-devops-nat}"
  cc_badge "$reboot_state"
  printf '\n'
  printf '%s' "$CC_BLUE"
  cc_double_rule
  printf '%s' "$CC_RESET"
}

cc_storage_health() {
  "$REPO_ROOT/diagnostics/storage-doctor" --quiet || return $?
  "$REPO_ROOT/diagnostics/data-storage-doctor" --quiet
}

cc_kvm_create_ubuntu_interactive() {
  local cloud_image=''
  local ssh_key=''
  local canonical_key=''
  local -a args=()

  read -r -p 'Image Ubuntu cloud (.img) : ' cloud_image
  if [[ -z "$cloud_image" ]]; then
    printf 'Chemin image obligatoire.\n'
    cc_pause
    return 0
  fi
  read -r -p 'Clé SSH publique [défaut ~/.ssh/id_ed25519.pub] : ' ssh_key
  read -r -p 'Clé Canonical locale [optionnel] : ' canonical_key

  args=(--cloud-image "$cloud_image")
  [[ -n "$ssh_key" ]] && args+=(--ssh-key "$ssh_key")
  [[ -n "$canonical_key" ]] && args+=(--canonical-key-file "$canonical_key")
  cc_interactive_exec 'CRÉATION UBUNTU DEVOPS' "$REPO_ROOT/scripts/kvm/create_ubuntu_devops_vm.sh" "${args[@]}"
}

cc_kvm_create_windows_interactive() {
  local windows_iso=''
  local virtio_iso=''
  local windows_sha=''
  local virtio_sha=''

  read -r -p 'ISO Windows 11 : ' windows_iso
  read -r -p 'ISO VirtIO : ' virtio_iso
  read -r -p 'SHA-256 Windows de confiance : ' windows_sha
  read -r -p 'SHA-256 VirtIO de confiance : ' virtio_sha

  if [[ -z "$windows_iso" || -z "$virtio_iso" || -z "$windows_sha" || -z "$virtio_sha" ]]; then
    printf 'Les deux ISO et les deux SHA-256 de confiance sont obligatoires.\n'
    cc_pause
    return 0
  fi

  cc_interactive_exec 'CRÉATION WINDOWS 11' "$REPO_ROOT/scripts/kvm/create_windows11_vm.sh" \
    --windows-iso "$windows_iso" \
    --virtio-iso "$virtio_iso" \
    --windows-sha256 "$windows_sha" \
    --virtio-sha256 "$virtio_sha"
}

cc_kvm_menu() {
  local choice=''
  while true; do
    cc_clear
    cc_header
    cc_section '6 — KVM / MACHINES VIRTUELLES'
    cc_option 1 'Virtualization doctor' 'KVM / libvirt / pool / réseau'
    cc_option 2 'Contrôler guard réseau' 'fail-closed'
    cc_option 3 'Réconcilier guard réseau' 'emergency → normal'
    cc_option 4 'Certification runtime KVM' 'Ubuntu + Windows + isolation'
    cc_option 5 'Rafraîchir accès Nautilus aux VM'
    cc_option 6 'Créer Ubuntu DevOps' 'image signée Canonical + cloud-init'
    cc_option 7 'Créer Windows 11' 'ISO + VirtIO + 2 SHA-256 obligatoires'
    cc_option 0 'Retour'
    read -r -p 'Choix : ' choice
    case "$choice" in
      1) cc_interactive_exec 'VIRTUALIZATION DOCTOR' "$REPO_ROOT/diagnostics/virtualization-doctor" ;;
      2) cc_interactive_exec 'KVM NETWORK GUARD — CHECK' sudo "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh" check ;;
      3)
        if cc_confirm 'Réconcilier les règles KVM fail-closed ?'; then
          cc_interactive_exec 'KVM NETWORK GUARD — RECONCILE' sudo "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh" reconcile
        fi
        ;;
      4) cc_interactive_exec 'KVM RUNTIME CERTIFICATION' "$REPO_ROOT/scripts/kvm/runtime_certification.sh" ;;
      5) cc_interactive_exec 'NAUTILUS VM ACCESS' "$REPO_ROOT/scripts/kvm/configure_nautilus_vm_access.sh" refresh ;;
      6) cc_kvm_create_ubuntu_interactive ;;
      7) cc_kvm_create_windows_interactive ;;
      0) return 0 ;;
      *) printf 'Choix invalide.\n'; sleep 1 ;;
    esac
  done
}

cc_doctor_menu() {
  local choice=''
  while true; do
    cc_clear
    cc_header
    cc_section '4 — DIAGNOSTICS & SANTÉ'
    cc_option 1 'Diagnostic global' 'synthèse workstation'
    cc_option 2 'Baseline matérielle' 'CPU / RAM / NVMe'
    cc_option 3 'Kernel / B580 / xe' 'N/N-1 + bindings'
    cc_option 4 'Graphics / compute' 'Vulkan / VA-API / OpenCL'
    cc_option 5 'Stockage / T705 / data' 'NVMe + /data EXT4'
    cc_option 6 'Affichage 1440p / 240 Hz' 'EDID / VRR / HDR'
    cc_option 7 'GNOME / Desktop' 'Wayland / extensions / portals'
    cc_option 8 'Applications' 'catalogue et runtime'
    cc_option 9 'Multimédia / codecs'
    cc_option 10 'Gaming / Steam / Vulkan' 'profil Golden obligatoire'
    cc_option 11 'Virtualisation / KVM'
    cc_option 12 'Backup / recovery'
    cc_option 0 'Retour'
    read -r -p 'Choix : ' choice
    case "$choice" in
      1) cc_interactive_exec 'DIAGNOSTIC GLOBAL' "$REPO_ROOT/diagnostic.sh" ;;
      2) cc_interactive_exec 'BASELINE DOCTOR' "$REPO_ROOT/diagnostics/baseline-doctor" status ;;
      3) cc_interactive_exec 'KERNEL DOCTOR' "$REPO_ROOT/diagnostics/kernel-doctor" ;;
      4) cc_interactive_exec 'GRAPHICS DOCTOR' "$REPO_ROOT/diagnostics/graphics-doctor" ;;
      5) cc_interactive_exec 'STOCKAGE T705 + DATA' cc_storage_health ;;
      6) cc_interactive_exec 'DISPLAY DOCTOR' "$REPO_ROOT/diagnostics/display-doctor" ;;
      7) cc_interactive_exec 'GNOME DOCTOR' "$REPO_ROOT/diagnostics/gnome-doctor" ;;
      8) cc_interactive_exec 'APPLICATIONS DOCTOR' "$REPO_ROOT/diagnostics/applications-doctor" ;;
      9) cc_interactive_exec 'MEDIA DOCTOR' "$REPO_ROOT/diagnostics/media-doctor" ;;
      10) cc_interactive_exec 'GAMING DOCTOR' "$REPO_ROOT/diagnostics/gaming-doctor" ;;
      11) cc_interactive_exec 'VIRTUALIZATION DOCTOR' "$REPO_ROOT/diagnostics/virtualization-doctor" ;;
      12) cc_interactive_exec 'BACKUP DOCTOR' "$REPO_ROOT/diagnostics/backup-doctor" ;;
      0) return 0 ;;
      *) printf 'Choix invalide.\n'; sleep 1 ;;
    esac
  done
}

cc_main_menu() {
  local choice=''
  while true; do
    cc_clear
    cc_header
    cc_section 'SOCLES OPÉRATEUR'
    cc_option 1 'Installation & convergence' 'préflight / backup / APPLY'
    cc_option 2 'Mises à jour' 'Fedora / Flatpak / kernel / firmware'
    cc_option 3 'Sauvegarde & restauration' 'Restic / staging / DR'
    cc_option 4 'Diagnostics & santé' 'hardware / desktop / gaming / data'
    cc_option 5 'Kernel & boot' 'latest-stable / N-N-1 / recovery'
    cc_option 6 'KVM / machines virtuelles' 'réseau fail-closed / runtime'
    cc_option 7 'Maintenance' 'état et réparations ciblées'
    cc_option 8 'Certification' 'baseline / preuves / Golden'
    cc_option 9 'Logs & preuves' 'traçabilité opérateur'
    cc_option 0 'Quitter'
    printf '\n%sLes opérations critiques conservent leurs garde-fous natifs.%s\n' "$CC_DIM" "$CC_RESET"
    read -r -p 'Choix : ' choice
    case "$choice" in
      1) cc_install_menu ;;
      2) cc_update_menu ;;
      3) cc_backup_menu ;;
      4) cc_doctor_menu ;;
      5) cc_kernel_menu ;;
      6) cc_kvm_menu ;;
      7) cc_maintenance_menu ;;
      8) cc_cert_menu ;;
      9) cc_logs_menu ;;
      0) return 0 ;;
      *) printf 'Choix invalide.\n'; sleep 1 ;;
    esac
  done
}

cc_help() {
  cat <<'EOF'
FEDORA GOLDEN WORKSTATION — Workstation Control Center

Usage:
  ./control.sh                                      Menu interactif
  ./control.sh status                               Tableau de bord read-only
  ./control.sh install dry-run|backup|apply
  ./control.sh update check|all|dnf|flatpak|firmware
  ./control.sh update status|log|reboot|finalize
  ./control.sh backup now|now-with-vms|daily|list|check|deep|restore [snapshot]|dr-plan|prune
  ./control.sh doctor all|baseline|kernel|graphics|storage|data|display|gnome|apps|media|gaming|kvm|backup
  ./control.sh kernel status|doctor|install-latest|prune|rollback|rollback-fedora
  ./control.sh kvm status|guard-check|guard-reconcile|certify|nautilus-refresh
  ./control.sh kvm create-ubuntu --cloud-image PATH [--ssh-key PATH] [--canonical-key-file PATH]
  ./control.sh kvm create-windows --windows-iso PATH --virtio-iso PATH --windows-sha256 HASH --virtio-sha256 HASH
  ./control.sh cert status|record-suspend|certify|baseline-status|baseline-certify
  ./control.sh cert archive DESTINATION PAYLOAD [PAYLOAD ...]
  ./control.sh logs list|tail|boot-failure|retention|prune
  ./control.sh validate help

Compatibilité : ./menu.sh lance le même centre de contrôle.
NO_COLOR=1 désactive les couleurs ANSI.
EOF
}

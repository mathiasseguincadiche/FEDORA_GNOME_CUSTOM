#!/usr/bin/env bash
# Workstation Control Center — operator UI and dispatcher only.
# Business logic remains in install.sh, diagnostics/* and scripts/*.
# REPO_ROOT, STATE_ROOT, LOG_ROOT, REPORT_ROOT and versioned config are loaded by bootstrap.

CONTROL_WIDTH=86
CC_RESET=''
CC_BOLD=''
CC_DIM=''
CC_BLUE=''
CC_CYAN=''
CC_GREEN=''
CC_YELLOW=''
CC_RED=''
CC_MAGENTA=''

cc_init_colors() {
  if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
    CC_RESET=$'\033[0m'
    CC_BOLD=$'\033[1m'
    CC_DIM=$'\033[2m'
    CC_BLUE=$'\033[34m'
    CC_CYAN=$'\033[36m'
    CC_GREEN=$'\033[32m'
    CC_YELLOW=$'\033[33m'
    CC_RED=$'\033[31m'
    CC_MAGENTA=$'\033[35m'
  fi
}

cc_repeat() {
  local char="$1"
  local count="${2:-$CONTROL_WIDTH}"
  local i
  for ((i = 0; i < count; i++)); do
    printf '%s' "$char"
  done
}

cc_rule() {
  cc_repeat '─'
  printf '\n'
}

cc_double_rule() {
  cc_repeat '═'
  printf '\n'
}

cc_clear() {
  if [[ -t 1 ]] && command_exists clear; then
    clear
  fi
}

cc_pause() {
  local pause_value=''
  if [[ -t 0 ]]; then
    read -r -p 'Appuyez sur Entrée pour continuer… ' pause_value
  fi
}

cc_badge() {
  local state="${1^^}"
  local color="$CC_DIM"
  case "$state" in
    PASS|OK|CLEAN|VALID|NORMAL) color="$CC_GREEN" ;;
    WARN|DIRTY|PENDING|REBOOT|STALE) color="$CC_YELLOW" ;;
    KO|FAIL|FAILED|BLOCKED) color="$CC_RED" ;;
    EXPECTED|DEFERRED|N/A|UNKNOWN) color="$CC_CYAN" ;;
  esac
  printf '%s[%-8s]%s' "$color" "$state" "$CC_RESET"
}

cc_version() {
  if [[ -r "$REPO_ROOT/VERSION" ]]; then
    tr -d '[:space:]' < "$REPO_ROOT/VERSION"
  else
    printf 'unknown'
  fi
}

cc_project_sha() {
  local sha=''
  sha="$(repo_commit)"
  if [[ "$sha" =~ ^[0-9a-fA-F]{40}$ ]]; then
    printf '%.10s' "$sha"
  else
    printf '%s' "$sha"
  fi
}

cc_fedora_version() {
  local os_id=''
  local version=''
  if [[ ! -r /etc/os-release ]]; then
    printf 'N/A'
    return 0
  fi
  os_id="$(awk -F= '$1=="ID" {gsub(/"/,"",$2); print $2; exit}' /etc/os-release)"
  if [[ "$os_id" != fedora ]]; then
    printf 'N/A'
    return 0
  fi
  version="$(awk -F= '$1=="VERSION_ID" {gsub(/"/,"",$2); print $2; exit}' /etc/os-release)"
  printf '%s' "${version:-unknown}"
}

cc_git_state() {
  if ! command_exists git; then
    printf 'UNKNOWN'
    return 0
  fi
  if ! git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'UNKNOWN'
    return 0
  fi
  if [[ -z "$(git -C "$REPO_ROOT" status --porcelain --untracked-files=normal 2>/dev/null)" ]]; then
    printf 'CLEAN'
  else
    printf 'DIRTY'
  fi
}

cc_marker_value() {
  local file="$1"
  local key="$2"
  [[ -r "$file" ]] || return 1
  awk -F= -v wanted="$key" '$1==wanted {sub(/^[^=]*=/, ""); print; exit}' "$file"
}

cc_backup_state() {
  local marker="$STATE_ROOT/last-full-backup.ok"
  local marker_commit=''
  if [[ ! -r "$marker" ]]; then
    printf 'PENDING'
    return 0
  fi
  marker_commit="$(cc_marker_value "$marker" commit || true)"
  if [[ -n "$marker_commit" && "$marker_commit" == "$(repo_commit)" ]]; then
    printf 'PASS'
  else
    printf 'WARN'
  fi
}

cc_backup_detail() {
  local marker="$STATE_ROOT/last-full-backup.ok"
  local utc=''
  if [[ ! -r "$marker" ]]; then
    printf 'aucune preuve'
    return 0
  fi
  utc="$(cc_marker_value "$marker" utc || true)"
  printf '%s' "${utc:-preuve présente}"
}

cc_cert_state() {
  local marker="$STATE_ROOT/final/certified.ok"
  local expected=''
  if [[ ! -s "$marker" ]]; then
    printf 'PENDING'
    return 0
  fi
  expected="$(workstation_runtime_fingerprint 2>/dev/null || true)"
  if [[ -n "$expected" ]] && grep -Fxq "fingerprint=$expected" "$marker"; then
    printf 'VALID'
  else
    printf 'STALE'
  fi
}

cc_gpu_detail() {
  local dev
  local vendor=''
  local device=''
  local driver=''
  if ! runtime_is_baremetal; then
    printf 'preuve physique différée'
    return 0
  fi
  for dev in /sys/bus/pci/devices/*; do
    [[ -r "$dev/vendor" && -r "$dev/device" ]] || continue
    read -r vendor < "$dev/vendor"
    read -r device < "$dev/device"
    if [[ "${vendor,,}" == 0x8086 && "${device,,}" == 0xe20b ]]; then
      driver='sans pilote'
      if [[ -L "$dev/driver" ]]; then
        driver="$(basename "$(readlink -f "$dev/driver")")"
      fi
      printf 'Arc B580 / %s' "$driver"
      return 0
    fi
  done
  printf 'Arc B580 non détectée'
}

cc_kvm_state() {
  if ! runtime_is_baremetal; then
    printf 'EXPECTED'
    return 0
  fi
  if ! command_exists virsh; then
    printf 'WARN'
    return 0
  fi
  if virsh -c "${LIBVIRT_URI:-qemu:///system}" net-info "${KVM_NETWORK_NAME:-devops-nat}" >/dev/null 2>&1; then
    printf 'PASS'
  else
    printf 'WARN'
  fi
}

cc_reboot_state() {
  if ! command_exists needs-restarting; then
    printf 'N/A'
    return 0
  fi
  if needs-restarting -r >/dev/null 2>&1; then
    printf 'OK'
  else
    printf 'REBOOT'
  fi
}

cc_header() {
  local version fedora runtime kernel sha gpu
  local git_state backup_state backup_detail cert_state kvm_state reboot_state
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

  printf '%s%s' "$CC_BLUE" "$CC_BOLD"
  cc_double_rule
  printf '%s' "$CC_RESET"
  printf '%s%s  FEDORA GOLDEN WORKSTATION — CENTRE DE CONTRÔLE%s\n' "$CC_BOLD" "$CC_CYAN" "$CC_RESET"
  printf '%s' "$CC_BLUE"
  cc_double_rule
  printf '%s' "$CC_RESET"
  printf '  Projet      %-10s  SHA %-10s  Fedora %-6s  Runtime %-10s\n' "$version" "$sha" "$fedora" "$runtime"
  printf '  Kernel      %-32s Politique vanilla/stable latest-stable\n' "$kernel"
  printf '  GPU         %-32s Git      ' "$gpu"
  cc_badge "$git_state"
  printf '\n'
  printf '  Backup      '
  cc_badge "$backup_state"
  printf ' %-24s Certification ' "$backup_detail"
  cc_badge "$cert_state"
  printf '\n'
  printf '  KVM         '
  cc_badge "$kvm_state"
  printf ' %-24s Reboot        ' "${KVM_NETWORK_NAME:-devops-nat}"
  cc_badge "$reboot_state"
  printf '\n'
  printf '%s' "$CC_BLUE"
  cc_double_rule
  printf '%s' "$CC_RESET"
}

cc_section() {
  printf '\n%s%s%s%s\n' "$CC_BOLD" "$CC_MAGENTA" "$1" "$CC_RESET"
  cc_rule
}

cc_option() {
  printf '  %s[%s]%s %-31s %s%s%s\n' "$CC_CYAN" "$1" "$CC_RESET" "$2" "$CC_DIM" "${3:-}" "$CC_RESET"
}

cc_result() {
  local rc="$1"
  if ((rc == 0)); then
    printf '\n%s✓ Opération terminée avec succès.%s\n' "$CC_GREEN" "$CC_RESET"
  else
    printf '\n%s✗ Opération terminée avec rc=%s.%s\n' "$CC_RED" "$rc" "$CC_RESET"
  fi
}

cc_interactive_exec() {
  local title="$1"
  local rc=0
  shift
  cc_clear
  cc_header
  cc_section "$title"
  if "$@"; then
    rc=0
  else
    rc=$?
  fi
  cc_result "$rc"
  cc_pause
  return 0
}

cc_confirm() {
  local prompt="$1"
  local answer=''
  read -r -p "$prompt [o/N] : " answer
  case "${answer,,}" in
    o|oui|y|yes) return 0 ;;
    *) return 1 ;;
  esac
}

cc_show_module_plan() {
  awk -F'|' 'BEGIN {printf "%-22s %-14s %s\n", "MODULE", "SCOPE", "SCRIPT"} /^[[:space:]]*#/ || NF<4 {next} {printf "%-22s %-14s %s\n", $1, $2, $4}' "$REPO_ROOT/manifests/module-plan.conf"
}

cc_show_kernel_inventory() {
  printf 'Kernel actif : %s\n\n' "$(uname -r)"
  if command_exists rpm; then
    rpm -qa 'kernel*' 2>/dev/null | sort -V || true
  else
    printf 'rpm indisponible dans cet environnement.\n'
  fi
  printf '\nPolitique versionnée :\n'
  printf '  Golden             kernel-vanilla/stable\n'
  printf '  Cible              latest stable upstream\n'
  printf '  Minimum actuel     %s\n' "${KERNEL_MIN_VERSION:-non défini}"
  printf '  Fedora fallback    %s\n' "${KERNEL_KEEP_FEDORA_FALLBACK:-true}"
}

cc_show_logs() {
  printf 'Derniers runs :\n'
  find "$LOG_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' 2>/dev/null | sort -r | head -n 10 || true
  printf '\nRapports :\n'
  find "$REPORT_ROOT" -maxdepth 1 -type f -printf '  %f\n' 2>/dev/null | sort | tail -n 15 || true
  printf '\nPreuves d’état :\n'
  find "$STATE_ROOT" -maxdepth 2 -type f \( -name '*.ok' -o -name '*.json' \) -printf '  %P\n' 2>/dev/null | sort | head -n 30 || true
}

cc_tail_latest_log() {
  local latest=''
  latest="$(find "$LOG_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort -r | head -n 1)"
  if [[ -z "$latest" || ! -r "$LOG_ROOT/$latest/main.log" ]]; then
    printf 'Aucun main.log disponible.\n'
    return 0
  fi
  printf '=== %s ===\n' "$LOG_ROOT/$latest/main.log"
  tail -n 80 "$LOG_ROOT/$latest/main.log"
}

cc_system_snapshot() {
  printf 'Charge / mémoire :\n'
  uptime || true
  free -h 2>/dev/null || true
  printf '\nVolumes :\n'
  if ! df -hT / "${KVM_DATA_MOUNT:-/data}" 2>/dev/null; then
    df -hT / 2>/dev/null || true
  fi
  printf '\nServices systemd en échec :\n'
  if ! systemctl --failed --no-pager 2>/dev/null; then
    printf 'systemd non disponible dans cet environnement.\n'
  fi
}

cc_install_menu() {
  local choice=''
  while true; do
    cc_clear
    cc_header
    cc_section '1 — INSTALLATION & CONVERGENCE'
    cc_option 1 'Préflight complet' 'non mutant'
    cc_option 2 'Préparer backup pré-APPLY' 'fail-closed'
    cc_option 3 'Installation complète' 'APPLY réel protégé'
    cc_option 4 'État baseline matérielle' 'read-only'
    cc_option 5 'Plan des modules' 'ordre de convergence'
    cc_option 0 'Retour'
    read -r -p 'Choix : ' choice
    case "$choice" in
      1) cc_interactive_exec 'PRÉFLIGHT COMPLET' "$REPO_ROOT/install.sh" --dry-run ;;
      2) cc_interactive_exec 'BACKUP PRÉ-APPLY' "$REPO_ROOT/prepare-preapply-backup.sh" ;;
      3)
        if cc_confirm 'Lancer le chemin APPLY protégé ?'; then
          cc_interactive_exec 'INSTALLATION COMPLÈTE — APPLY PROTÉGÉ' "$REPO_ROOT/install.sh" --apply
        fi
        ;;
      4) cc_interactive_exec 'BASELINE MATÉRIELLE' "$REPO_ROOT/diagnostics/baseline-doctor" status ;;
      5) cc_interactive_exec 'PLAN DE CONVERGENCE' cc_show_module_plan ;;
      0) return 0 ;;
      *) printf 'Choix invalide.\n'; sleep 1 ;;
    esac
  done
}

cc_update_menu() {
  local choice=''
  while true; do
    cc_clear
    cc_header
    cc_section '2 — MISES À JOUR'
    cc_option 1 'Vérifier les mises à jour' 'Fedora + Flatpak + firmware'
    cc_option 2 'Mise à jour complète sécurisée' 'backup → DNF → Flatpak → diagnostic'
    cc_option 3 'Mise à jour Fedora seulement' 'DNF, backup obligatoire'
    cc_option 4 'Mise à jour Flatpak seulement'
    cc_option 5 'Firmware disponible' 'consultation uniquement'
    cc_option 0 'Retour'
    read -r -p 'Choix : ' choice
    case "$choice" in
      1) cc_interactive_exec 'VÉRIFICATION DES MISES À JOUR' "$REPO_ROOT/scripts/maintenance/update-system.sh" --check ;;
      2)
        if cc_confirm 'Créer un backup puis mettre à jour tout le système ?'; then
          cc_interactive_exec 'MISE À JOUR COMPLÈTE SÉCURISÉE' "$REPO_ROOT/scripts/maintenance/update-system.sh" --apply
        fi
        ;;
      3)
        if cc_confirm 'Créer un backup puis appliquer les mises à jour Fedora ?'; then
          cc_interactive_exec 'MISE À JOUR FEDORA' "$REPO_ROOT/scripts/maintenance/update-system.sh" --dnf-only
        fi
        ;;
      4) cc_interactive_exec 'MISE À JOUR FLATPAK' "$REPO_ROOT/scripts/maintenance/update-system.sh" --flatpak-only ;;
      5) cc_interactive_exec 'FIRMWARE DISPONIBLE — AUCUN FLASH' "$REPO_ROOT/scripts/maintenance/update-system.sh" --firmware-check ;;
      0) return 0 ;;
      *) printf 'Choix invalide.\n'; sleep 1 ;;
    esac
  done
}

cc_backup_menu() {
  local choice=''
  local snap=''
  while true; do
    cc_clear
    cc_header
    cc_section '3 — SAUVEGARDE & RESTAURATION'
    cc_option 1 'Backup complet HOST' 'Restic + intégrité'
    cc_option 2 'Backup complet + VM arrêtées'
    cc_option 3 'Backup utilisateur XDG' 'Bureau/Documents/Images/Vidéos/Musique'
    cc_option 4 'Lister les snapshots Restic'
    cc_option 5 'Vérifier repository Restic' 'doctor'
    cc_option 6 'Vérification profonde Restic'
    cc_option 7 'Restaurer vers staging' 'non destructif'
    cc_option 8 'Plan Disaster Recovery'
    cc_option 0 'Retour'
    read -r -p 'Choix : ' choice
    case "$choice" in
      1) cc_interactive_exec 'BACKUP COMPLET HOST' "$REPO_ROOT/scripts/backup/backup-now.sh" ;;
      2) cc_interactive_exec 'BACKUP COMPLET + VM' "$REPO_ROOT/scripts/backup/backup-now.sh" --include-vms ;;
      3) cc_interactive_exec 'BACKUP UTILISATEUR XDG' env FEDORA_GNOME_CUSTOM_REPO="$REPO_ROOT" "$REPO_ROOT/scripts/backup/daily-user-backup.sh" ;;
      4) cc_interactive_exec 'SNAPSHOTS RESTIC' "$REPO_ROOT/scripts/backup/restore.sh" list ;;
      5) cc_interactive_exec 'BACKUP / RECOVERY DOCTOR' "$REPO_ROOT/diagnostics/backup-doctor" ;;
      6) cc_interactive_exec 'VÉRIFICATION PROFONDE RESTIC' "$REPO_ROOT/diagnostics/backup-doctor" --deep ;;
      7)
        read -r -p 'Snapshot [latest] : ' snap
        cc_interactive_exec 'RESTAURATION VERS STAGING' "$REPO_ROOT/scripts/backup/restore.sh" restore "${snap:-latest}"
        ;;
      8) cc_interactive_exec 'PLAN DISASTER RECOVERY' "$REPO_ROOT/scripts/backup/disaster-recovery.sh" ;;
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
    cc_option 1 'Diagnostic global'
    cc_option 2 'Baseline matérielle'
    cc_option 3 'Kernel / B580 / xe'
    cc_option 4 'Graphics / compute'
    cc_option 5 'Stockage / T705'
    cc_option 6 'Affichage 1440p / 240 Hz'
    cc_option 7 'GNOME / Desktop'
    cc_option 8 'Applications'
    cc_option 9 'Multimédia / codecs'
    cc_option 10 'Virtualisation / KVM'
    cc_option 11 'Backup / recovery'
    cc_option 0 'Retour'
    read -r -p 'Choix : ' choice
    case "$choice" in
      1) cc_interactive_exec 'DIAGNOSTIC GLOBAL' "$REPO_ROOT/diagnostic.sh" ;;
      2) cc_interactive_exec 'BASELINE DOCTOR' "$REPO_ROOT/diagnostics/baseline-doctor" status ;;
      3) cc_interactive_exec 'KERNEL DOCTOR' "$REPO_ROOT/diagnostics/kernel-doctor" ;;
      4) cc_interactive_exec 'GRAPHICS DOCTOR' "$REPO_ROOT/diagnostics/graphics-doctor" ;;
      5) cc_interactive_exec 'STORAGE DOCTOR' "$REPO_ROOT/diagnostics/storage-doctor" ;;
      6) cc_interactive_exec 'DISPLAY DOCTOR' "$REPO_ROOT/diagnostics/display-doctor" ;;
      7) cc_interactive_exec 'GNOME DOCTOR' "$REPO_ROOT/diagnostics/gnome-doctor" ;;
      8) cc_interactive_exec 'APPLICATIONS DOCTOR' "$REPO_ROOT/diagnostics/applications-doctor" ;;
      9) cc_interactive_exec 'MEDIA DOCTOR' "$REPO_ROOT/diagnostics/media-doctor" ;;
      10) cc_interactive_exec 'VIRTUALIZATION DOCTOR' "$REPO_ROOT/diagnostics/virtualization-doctor" ;;
      11) cc_interactive_exec 'BACKUP DOCTOR' "$REPO_ROOT/diagnostics/backup-doctor" ;;
      0) return 0 ;;
      *) printf 'Choix invalide.\n'; sleep 1 ;;
    esac
  done
}

cc_kernel_menu() {
  local choice=''
  while true; do
    cc_clear
    cc_header
    cc_section '5 — KERNEL & BOOT'
    cc_option 1 'Inventaire kernels' 'actif + paquets installés'
    cc_option 2 'Kernel doctor' 'Golden vanilla/stable'
    cc_option 3 'Vérifier mises à jour kernel' 'via DNF check'
    cc_option 4 'Rollback noyau Fedora' 'fallback de récupération'
    cc_option 5 'Collecter panne de boot'
    cc_option 0 'Retour'
    read -r -p 'Choix : ' choice
    case "$choice" in
      1) cc_interactive_exec 'INVENTAIRE KERNEL' cc_show_kernel_inventory ;;
      2) cc_interactive_exec 'KERNEL DOCTOR' "$REPO_ROOT/diagnostics/kernel-doctor" ;;
      3) cc_interactive_exec 'RECHERCHE MISES À JOUR KERNEL' "$REPO_ROOT/scripts/maintenance/update-system.sh" --check ;;
      4)
        if cc_confirm 'Basculer les paquets vers le noyau Fedora fallback ?'; then
          cc_interactive_exec 'ROLLBACK KERNEL FEDORA' "$REPO_ROOT/scripts/kernel/rollback-to-fedora.sh"
        fi
        ;;
      5) cc_interactive_exec 'COLLECTE PANNE DE BOOT' "$REPO_ROOT/scripts/collect-boot-failure.sh" ;;
      0) return 0 ;;
      *) printf 'Choix invalide.\n'; sleep 1 ;;
    esac
  done
}

cc_kvm_menu() {
  local choice=''
  while true; do
    cc_clear
    cc_header
    cc_section '6 — KVM / MACHINES VIRTUELLES'
    cc_option 1 'Virtualization doctor'
    cc_option 2 'Contrôler guard réseau' 'fail-closed'
    cc_option 3 'Réconcilier guard réseau' 'emergency → normal'
    cc_option 4 'Certification runtime KVM'
    cc_option 5 'Rafraîchir accès Nautilus aux VM'
    cc_option 6 'Créer Ubuntu DevOps'
    cc_option 7 'Créer Windows 11'
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
      6) cc_interactive_exec 'CRÉATION UBUNTU DEVOPS' "$REPO_ROOT/scripts/kvm/create_ubuntu_devops_vm.sh" ;;
      7) cc_interactive_exec 'CRÉATION WINDOWS 11' "$REPO_ROOT/scripts/kvm/create_windows11_vm.sh" ;;
      0) return 0 ;;
      *) printf 'Choix invalide.\n'; sleep 1 ;;
    esac
  done
}

cc_maintenance_menu() {
  local choice=''
  while true; do
    cc_clear
    cc_header
    cc_section '7 — MAINTENANCE'
    cc_option 1 'État système rapide' 'charge / RAM / disques / services KO'
    cc_option 2 'Réparer affichage certifié'
    cc_option 3 'Mesurer cold-start Nautilus'
    cc_option 4 'Suspend / resume doctor'
    cc_option 5 'Vérifier mises à jour' 'aucune mutation'
    cc_option 0 'Retour'
    read -r -p 'Choix : ' choice
    case "$choice" in
      1) cc_interactive_exec 'ÉTAT SYSTÈME RAPIDE' cc_system_snapshot ;;
      2) cc_interactive_exec 'RÉPARATION AFFICHAGE' "$REPO_ROOT/repair.sh" display ;;
      3) cc_interactive_exec 'NAUTILUS COLD START' "$REPO_ROOT/diagnostics/nautilus-coldstart-doctor" ;;
      4) cc_interactive_exec 'SUSPEND / RESUME DOCTOR' "$REPO_ROOT/diagnostics/suspend-doctor" ;;
      5) cc_interactive_exec 'VÉRIFICATION DES MISES À JOUR' "$REPO_ROOT/scripts/maintenance/update-system.sh" --check ;;
      0) return 0 ;;
      *) printf 'Choix invalide.\n'; sleep 1 ;;
    esac
  done
}

cc_cert_menu() {
  local choice=''
  while true; do
    cc_clear
    cc_header
    cc_section '8 — CERTIFICATION'
    cc_option 1 'Statut certification finale'
    cc_option 2 'Enregistrer cycle suspend'
    cc_option 3 'Certifier Golden Workstation'
    cc_option 4 'État baseline pré-APPLY'
    cc_option 5 'Certifier baseline pré-APPLY'
    cc_option 0 'Retour'
    read -r -p 'Choix : ' choice
    case "$choice" in
      1) cc_interactive_exec 'STATUT CERTIFICATION' "$REPO_ROOT/diagnostics/final-certification" status ;;
      2) cc_interactive_exec 'ENREGISTRER CYCLE SUSPEND' "$REPO_ROOT/diagnostics/final-certification" record-suspend ;;
      3)
        if cc_confirm 'Lancer la certification finale complète ?'; then
          cc_interactive_exec 'CERTIFICATION GOLDEN WORKSTATION' "$REPO_ROOT/diagnostics/final-certification" certify
        fi
        ;;
      4) cc_interactive_exec 'BASELINE STATUS' "$REPO_ROOT/diagnostics/baseline-doctor" status ;;
      5) cc_interactive_exec 'CERTIFICATION BASELINE' "$REPO_ROOT/diagnostics/baseline-doctor" certify ;;
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
    cc_option 0 'Retour'
    read -r -p 'Choix : ' choice
    case "$choice" in
      1) cc_interactive_exec 'LOGS & PREUVES' cc_show_logs ;;
      2) cc_interactive_exec 'DERNIER MAIN.LOG' cc_tail_latest_log ;;
      3) cc_interactive_exec 'COLLECTE PANNE DE BOOT' "$REPO_ROOT/scripts/collect-boot-failure.sh" ;;
      4) cc_interactive_exec 'SOURCE DE VÉRITÉ GIT' bash -c 'git -C "$1" status --short --branch; git -C "$1" rev-parse HEAD' _ "$REPO_ROOT" ;;
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
    cc_option 2 'Mises à jour' 'Fedora / Flatpak / kernel / firmware check'
    cc_option 3 'Sauvegarde & restauration' 'Restic / staging / DR'
    cc_option 4 'Diagnostics & santé' 'doctors par domaine'
    cc_option 5 'Kernel & boot' 'vanilla/stable + fallback Fedora'
    cc_option 6 'KVM / machines virtuelles' 'réseau fail-closed / runtime'
    cc_option 7 'Maintenance' 'état et réparations ciblées'
    cc_option 8 'Certification' 'baseline / suspend / Golden'
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
  ./control.sh                         Menu interactif
  ./control.sh status                  Tableau de bord read-only
  ./control.sh install dry-run|backup|apply
  ./control.sh update check|all|dnf|flatpak|firmware
  ./control.sh backup now|now-with-vms|daily|list|check|deep|restore [snapshot]|dr-plan
  ./control.sh doctor all|baseline|kernel|graphics|storage|display|gnome|apps|media|kvm|backup
  ./control.sh kernel status|doctor|rollback
  ./control.sh kvm status|guard-check|guard-reconcile|certify|nautilus-refresh|create-ubuntu|create-windows
  ./control.sh cert status|record-suspend|certify|baseline-status|baseline-certify
  ./control.sh logs list|tail|boot-failure

Compatibilité : ./menu.sh lance le même centre de contrôle.
NO_COLOR=1 désactive les couleurs ANSI.
EOF
}

cc_cli_dispatch() {
  local domain="${1:-help}"
  local action="${2:-}"
  local extra="${3:-}"
  case "$domain" in
    status) cc_header ;;
    install)
      case "$action" in
        dry-run) "$REPO_ROOT/install.sh" --dry-run ;;
        backup) "$REPO_ROOT/prepare-preapply-backup.sh" ;;
        apply) "$REPO_ROOT/install.sh" --apply ;;
        *) cc_help; return "$EXIT_USAGE" ;;
      esac
      ;;
    update)
      case "$action" in
        check) "$REPO_ROOT/scripts/maintenance/update-system.sh" --check ;;
        all) "$REPO_ROOT/scripts/maintenance/update-system.sh" --apply ;;
        dnf) "$REPO_ROOT/scripts/maintenance/update-system.sh" --dnf-only ;;
        flatpak) "$REPO_ROOT/scripts/maintenance/update-system.sh" --flatpak-only ;;
        firmware) "$REPO_ROOT/scripts/maintenance/update-system.sh" --firmware-check ;;
        *) cc_help; return "$EXIT_USAGE" ;;
      esac
      ;;
    backup)
      case "$action" in
        now) "$REPO_ROOT/scripts/backup/backup-now.sh" ;;
        now-with-vms) "$REPO_ROOT/scripts/backup/backup-now.sh" --include-vms ;;
        daily) FEDORA_GNOME_CUSTOM_REPO="$REPO_ROOT" "$REPO_ROOT/scripts/backup/daily-user-backup.sh" ;;
        list) "$REPO_ROOT/scripts/backup/restore.sh" list ;;
        check) "$REPO_ROOT/diagnostics/backup-doctor" ;;
        deep) "$REPO_ROOT/diagnostics/backup-doctor" --deep ;;
        restore) "$REPO_ROOT/scripts/backup/restore.sh" restore "${extra:-latest}" ;;
        dr-plan) "$REPO_ROOT/scripts/backup/disaster-recovery.sh" ;;
        *) cc_help; return "$EXIT_USAGE" ;;
      esac
      ;;
    doctor)
      case "$action" in
        all) "$REPO_ROOT/diagnostic.sh" ;;
        baseline) "$REPO_ROOT/diagnostics/baseline-doctor" status ;;
        kernel) "$REPO_ROOT/diagnostics/kernel-doctor" ;;
        graphics) "$REPO_ROOT/diagnostics/graphics-doctor" ;;
        storage) "$REPO_ROOT/diagnostics/storage-doctor" ;;
        display) "$REPO_ROOT/diagnostics/display-doctor" ;;
        gnome) "$REPO_ROOT/diagnostics/gnome-doctor" ;;
        apps) "$REPO_ROOT/diagnostics/applications-doctor" ;;
        media) "$REPO_ROOT/diagnostics/media-doctor" ;;
        kvm) "$REPO_ROOT/diagnostics/virtualization-doctor" ;;
        backup) "$REPO_ROOT/diagnostics/backup-doctor" ;;
        *) cc_help; return "$EXIT_USAGE" ;;
      esac
      ;;
    kernel)
      case "$action" in
        status) cc_show_kernel_inventory ;;
        doctor) "$REPO_ROOT/diagnostics/kernel-doctor" ;;
        rollback) "$REPO_ROOT/scripts/kernel/rollback-to-fedora.sh" ;;
        *) cc_help; return "$EXIT_USAGE" ;;
      esac
      ;;
    kvm)
      case "$action" in
        status) "$REPO_ROOT/diagnostics/virtualization-doctor" ;;
        guard-check) sudo "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh" check ;;
        guard-reconcile) sudo "$REPO_ROOT/scripts/kvm/kvm_network_guard.sh" reconcile ;;
        certify) "$REPO_ROOT/scripts/kvm/runtime_certification.sh" ;;
        nautilus-refresh) "$REPO_ROOT/scripts/kvm/configure_nautilus_vm_access.sh" refresh ;;
        create-ubuntu) "$REPO_ROOT/scripts/kvm/create_ubuntu_devops_vm.sh" ;;
        create-windows) "$REPO_ROOT/scripts/kvm/create_windows11_vm.sh" ;;
        *) cc_help; return "$EXIT_USAGE" ;;
      esac
      ;;
    cert)
      case "$action" in
        status) "$REPO_ROOT/diagnostics/final-certification" status ;;
        record-suspend) "$REPO_ROOT/diagnostics/final-certification" record-suspend ;;
        certify) "$REPO_ROOT/diagnostics/final-certification" certify ;;
        baseline-status) "$REPO_ROOT/diagnostics/baseline-doctor" status ;;
        baseline-certify) "$REPO_ROOT/diagnostics/baseline-doctor" certify ;;
        *) cc_help; return "$EXIT_USAGE" ;;
      esac
      ;;
    logs)
      case "$action" in
        list) cc_show_logs ;;
        tail) cc_tail_latest_log ;;
        boot-failure) "$REPO_ROOT/scripts/collect-boot-failure.sh" ;;
        *) cc_help; return "$EXIT_USAGE" ;;
      esac
      ;;
    help|-h|--help) cc_help ;;
    *) cc_help; return "$EXIT_USAGE" ;;
  esac
}

control_center_main() {
  cc_init_colors
  if (($# == 0)); then
    if [[ ! -t 0 ]]; then
      cc_help
      return "$EXIT_USAGE"
    fi
    cc_main_menu
  else
    cc_cli_dispatch "$@"
  fi
}

#!/usr/bin/env bash
# System updates behind ./control.sh update: check, prepare an offline DNF5 transaction
# after a full backup, reboot into it and finalize (kernel N, GRUB, Flatpak, doctors).
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/install_lock.sh"
install_lock_acquire || exit $?
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
source "$REPO_ROOT/lib/kernel_lifecycle.sh"
source "$REPO_ROOT/lib/gaming_repositories.sh"

UPDATE_STATE_FILE="$STATE_ROOT/last-system-update.status"
UPDATE_REBOOT_REQUIRED="unknown"
UPDATE_KERNEL_TARGET=""
UPDATE_KERNEL_PREVIOUS=""
UPDATE_KERNEL_DEFERRED="false"
UPDATE_SOURCE_BOOT_ID=""
UPDATE_TRANSACTION_COMMENT=""
UPDATE_PREPARED_TIMESTAMP=""

update_current_boot_id() { cat /proc/sys/kernel/random/boot_id; }

usage() {
  cat <<'EOF'
Usage: update-system.sh [ACTION]

  --check           Read-only overview: Fedora, Flatpak, firmware and offline state
  --apply           Backup + update Fedora and Flatpak; stage RPM changes offline when needed
  --dnf-only        Backup + prepare a Fedora-only DNF5 offline transaction, latest stable kernel included
  --offline-reboot  Reboot into the prepared DNF5 offline transaction
  --finalize        After normal boot: validate kernel N/N-1, DNF, Flatpak (full mode), firmware and doctor
  --offline-status  Show project marker and DNF5 offline status
  --offline-log     Show the latest DNF5 offline transaction log
  --flatpak-only    Update Flatpak applications only
  --firmware-check  Show firmware updates only; never flashes firmware
  --scope           Explain which update domains are managed, external or pinned
EOF
}

require_fedora() {
  [[ -r /etc/os-release ]] || { ui_error '/etc/os-release unavailable'; exit "$EXIT_PRECHECK_FAILED"; }
  grep -Eq '^ID=fedora$|^ID="fedora"$' /etc/os-release || { ui_error 'This updater is Fedora-only'; exit "$EXIT_PRECHECK_FAILED"; }
  fedora_require_selected || { ui_error 'Golden updater requires the selected promoted Fedora release'; exit "$EXIT_PRECHECK_FAILED"; }
}

require_baremetal_update() {
  runtime_is_baremetal || { ui_error "Mutating updates are bare-metal only (runtime=$RUNTIME_ENVIRONMENT)"; exit "$EXIT_SECURITY_BLOCK"; }
}

require_dnf5() {
  command_exists dnf5 || { ui_error 'dnf5 is required by the Golden offline-update policy'; exit "$EXIT_PRECHECK_FAILED"; }
}

update_state_value() {
  evidence_marker_value "$UPDATE_STATE_FILE" "$1" 2>/dev/null || true
}

write_update_state() {
  local phase="$1" mode="$2" doctor_rc="${3:-pending}"
  local kernel_target kernel_previous
  kernel_target="$UPDATE_KERNEL_TARGET"
  kernel_previous="$UPDATE_KERNEL_PREVIOUS"
  [[ -n "$kernel_target" ]] || kernel_target="$(update_state_value kernel_target)"
  [[ -n "$kernel_previous" ]] || kernel_previous="$(update_state_value kernel_previous)"
  [[ -n "$kernel_target" ]] || kernel_target=none
  [[ -n "$kernel_previous" ]] || kernel_previous=none
  [[ "$kernel_target" == none ]] || kernel_lifecycle_release_is_stable "$kernel_target" || { ui_error 'Invalid kernel target in update state'; return "$EXIT_CONFIG_FAILED"; }
  [[ "$kernel_previous" == none ]] || kernel_lifecycle_release_is_stable "$kernel_previous" || { ui_error 'Invalid previous kernel in update state'; return "$EXIT_CONFIG_FAILED"; }
  {
    printf 'schema=3\n'
    printf 'utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'commit=%s\n' "$(repo_commit)"
    printf 'effective_config_sha256=%s\n' "$(effective_config_sha256)"
    printf 'phase=%s\n' "$phase"
    printf 'mode=%s\n' "$mode"
    printf 'doctor_rc=%s\n' "$doctor_rc"
    printf 'reboot_required=%s\n' "$UPDATE_REBOOT_REQUIRED"
    printf 'kernel_running=%s\n' "$(uname -r)"
    printf 'kernel_policy=rolling-n-nminus1\n'
    printf 'kernel_target=%s\n' "$kernel_target"
    printf 'kernel_deferred=%s\n' "${UPDATE_KERNEL_DEFERRED:-false}"
    printf 'kernel_previous=%s\n' "$kernel_previous"
    printf 'kernel_lock_sha256=%s\n' "$(kernel_lifecycle_lock_hash)"
    printf 'kernel_max_installed=%s\n' "$(kernel_lifecycle_max_installed)"
    printf 'source_boot_id=%s\n' "${UPDATE_SOURCE_BOOT_ID:-$(update_state_value source_boot_id)}"
    printf 'transaction_comment=%s\n' "${UPDATE_TRANSACTION_COMMENT:-$(update_state_value transaction_comment)}"
    printf 'prepared_timestamp=%s\n' "${UPDATE_PREPARED_TIMESTAMP:-$(update_state_value prepared_timestamp)}"
  } | evidence_atomic_write "$UPDATE_STATE_FILE" 0600
}

require_current_update_state() {
  local phase mode
  [[ -s "$UPDATE_STATE_FILE" ]] || { ui_error 'No project-owned offline update state exists'; return "$EXIT_PRECHECK_FAILED"; }
  [[ "$(update_state_value commit)" == "$(repo_commit)" ]] || { ui_error 'Update state belongs to another Git commit'; return "$EXIT_SECURITY_BLOCK"; }
  [[ "$(update_state_value effective_config_sha256)" == "$(effective_config_sha256)" ]] || { ui_error 'Update state belongs to another effective configuration'; return "$EXIT_SECURITY_BLOCK"; }
  local target
  target="$(update_state_value kernel_target)"
  [[ "$target" == none ]] || kernel_lifecycle_release_is_stable "$target" || { ui_error 'Invalid recorded kernel target'; return "$EXIT_CONFIG_FAILED"; }
  [[ "$(update_state_value kernel_lock_sha256)" == "$(kernel_lifecycle_lock_hash)" ]] || {
    ui_error 'The exact kernel transaction lock changed after preparation.'
    return "$EXIT_SECURITY_BLOCK"
  }
  phase="$(update_state_value phase)"; mode="$(update_state_value mode)"
  [[ "$phase" == prepared || "$phase" == reboot-requested ]] || { ui_error "Offline update state is not pending: phase=${phase:-unknown}"; return "$EXIT_PRECHECK_FAILED"; }
  [[ "$mode" == full || "$mode" == dnf-only ]] || { ui_error "Invalid offline update mode: ${mode:-unknown}"; return "$EXIT_PRECHECK_FAILED"; }
}

check_dnf() {
  local rc=0
  require_dnf5
  printf '\n--- Fedora packages ---\n'
  if dnf5 check-upgrade; then
    ui_check PASS 'Mises à jour Fedora' 'aucun paquet à mettre à jour signalé'
  else
    rc=$?
    if ((rc == 100)); then
      ui_check WARN 'Mises à jour Fedora' 'des mises à jour sont disponibles'
    else
      ui_check KO 'Mises à jour Fedora' "recherche DNF5 impossible (rc=$rc)"
      return "$rc"
    fi
  fi
}

check_kernel() {
  local rc=0
  printf '\n--- Kernel Vanilla rolling N/N-1 ---\n'
  if is_true "${ENABLE_KERNEL_VANILLA_STABLE:-true}"; then
    kernel_lifecycle_status || rc=$?
    if ((rc != 0)); then
      ui_check KO 'État du noyau' "inventaire du canal impossible (rc=$rc) ; noyau non vérifié"
      return "$rc"
    fi
  else
    ui_check EXPECTED 'Noyau Vanilla' 'désactivé par la configuration'
  fi
}

check_flatpak() {
  local pending='' rc=0
  printf '\n--- Flatpak ---\n'
  if ! command_exists flatpak; then ui_check EXPECTED 'Mises à jour Flatpak' 'Flatpak absent'; return 0; fi
  pending="$(flatpak remote-ls --updates --columns=application 2>&1)" || rc=$?
  if ((rc != 0)); then
    ui_check KO 'Mises à jour Flatpak' "consultation impossible (rc=$rc) ; état à jour non vérifié"
    ui_info "Flatpak diagnostic: ${pending//$'\n'/ }"
    return "$rc"
  fi
  pending="$(sed '/^[[:space:]]*$/d' <<<"$pending")"
  if [[ -n "$pending" ]]; then printf '%s\n' "$pending"; ui_check WARN 'Mises à jour Flatpak' 'des mises à jour sont disponibles'; else ui_check PASS 'Mises à jour Flatpak' 'aucune mise à jour disponible signalée'; fi
}

# Steam's Fedora-owned repository is enabled only for its installation by the
# Gaming module. An ordinary DNF upgrade must enable it again if Steam is
# installed, otherwise "update all" could silently omit the Steam RPM.
# Only the exact Fedora-owned repository definition is permitted.
update_steam_repository_flag() {
  local repo_file owner repos
  command_exists rpm || return 0
  rpm -q steam >/dev/null 2>&1 || return 0
  repo_file="$(gaming_steam_repository_file /)" || {
    ui_error 'Steam RPM installé, mais définition de son dépôt Fedora introuvable'
    return "$EXIT_PRECHECK_FAILED"
  }
  if [[ ! -f "$repo_file" || -L "$repo_file" ]] || ! grep -Fxq '[rpmfusion-nonfree-steam]' "$repo_file"; then
    ui_error 'Définition du dépôt Steam non conforme (fichier ou section inattendue)'
    return "$EXIT_SECURITY_BLOCK"
  fi
  owner="$(rpm -qf --qf '%{NAME}\n' "$repo_file" 2>/dev/null)" || return "$EXIT_PRECHECK_FAILED"
  [[ "$owner" == fedora-workstation-repositories ]] || {
    ui_error 'Le dépôt Steam ne provient pas du paquet Fedora fedora-workstation-repositories'
    return "$EXIT_SECURITY_BLOCK"
  }
  repos="$(dnf5 repolist --all 2>/dev/null)" || {
    ui_error 'Impossible de consulter les dépôts DNF5 pour Steam RPM'
    return "$EXIT_PRECHECK_FAILED"
  }
  awk '$1 == "rpmfusion-nonfree-steam" { found=1 } END { exit !found }' <<<"$repos" || {
    ui_error 'Dépôt Steam RPM installé mais invisible pour DNF5'
    return "$EXIT_PRECHECK_FAILED"
  }
  printf '%s\n' '--enablerepo=rpmfusion-nonfree-steam'
}

check_update_scope() {
  local steam_repo='' rc=0
  printf '\n--- Périmètre de maintenance ---\n'
  ui_check INFO 'RPM / codecs / Mesa' 'DNF5 : paquets installés, dans les dépôts actifs et disponibles'
  ui_check INFO 'Noyau / microcode' 'RPM et noyau N/N-1 protégé ; version amont éventuellement reportée'
  if command_exists rpm && rpm -q steam >/dev/null 2>&1; then
    steam_repo="$(update_steam_repository_flag)" || rc=$?
    if ((rc == 0)) && [[ "$steam_repo" == --enablerepo=rpmfusion-nonfree-steam ]]; then
      ui_check PASS 'Dépôt Steam RPM' 'source Fedora vérifiée et disponible pour la prochaine mise à jour DNF5'
    else
      ui_check KO 'Dépôt Steam RPM' 'source non vérifiable ; corriger le dépôt avant la mise à jour RPM'
      return "$EXIT_PRECHECK_FAILED"
    fi
    ui_check EXPECTED 'Proton / jeux Steam' 'mises à jour gérées par Steam, hors DNF5 et centre de contrôle'
  else
    ui_check EXPECTED 'Steam RPM / Proton' 'aucun Steam RPM installé ; mise à jour Steam non revendiquée'
  fi
  if is_true "${ENABLE_GNOME_EXTENSIONS:-false}"; then
    ui_check INFO 'Extensions GNOME' 'RPM via DNF5 ; artefacts épinglés à revoir et approuver séparément'
  else
    ui_check EXPECTED 'Extensions GNOME' 'profil des extensions du projet désactivé'
  fi
  ui_check EXPECTED 'AppImage autonomes' 'hors DNF5/Flatpak ; mise à jour et validation propres à chaque éditeur'
  ui_check EXPECTED 'Firmware périphériques' 'fwupdmgr consulte les versions ; aucun flash automatique'
  ui_check INFO 'Modules et configuration' 'modifications à reconverger puis valider via les diagnostics et Gates applicables'
}

check_updates_overview() {
  local failed=0
  check_dnf || failed=1
  check_kernel || failed=1
  check_flatpak || failed=1
  check_firmware || failed=1
  check_update_scope || failed=1
  show_offline_status
  if ((failed != 0)); then
    ui_check KO 'Bilan mises à jour' 'au moins un domaine non vérifié ; consulter les contrôles ci-dessus'
    return "$EXIT_PRECHECK_FAILED"
  fi
}

check_firmware() {
  local response='' rc=0
  printf '\n--- Firmware ---\n'
  if ! command_exists fwupdmgr; then ui_check EXPECTED 'Firmware matériel' 'fwupdmgr absent'; return 0; fi
  response="$(fwupdmgr get-updates --no-metadata-check 2>&1)" || rc=$?
  [[ -z "$response" ]] || printf '%s\n' "$response"
  if ((rc == 0)); then
    ui_check PASS 'Consultation firmware' 'terminée selon les métadonnées locales ; aucun flash ; état matériel non certifié'
  else
    ui_check WARN 'Consultation firmware' "retour fwupdmgr=$rc : résultat indéterminé (ceci ne signifie pas « aucun firmware à mettre à jour ») ; aucun flash"
    return "$EXIT_PRECHECK_FAILED"
  fi
}

show_offline_status() {
  printf '\n--- Project update state ---\n'
  if [[ -s "$UPDATE_STATE_FILE" ]]; then cat "$UPDATE_STATE_FILE"; else printf 'none\n'; fi
  printf '\n--- DNF5 offline state ---\n'
  if command_exists dnf5; then sudo -n dnf5 offline status 2>&1 || dnf5 offline status 2>&1 || true; else printf 'dnf5 unavailable\n'; fi
}

mandatory_preupdate_backup() {
  ui_banner 'FEDORA WORKSTATION UPDATE' 'MANDATORY PRE-UPDATE BORG BACKUP'
  "$REPO_ROOT/scripts/backup/backup-now.sh"
  ui_check PASS 'Pre-update backup' 'full snapshot + integrity check completed'
}

prepare_kernel_rolling_target() {
  if ! is_true "${ENABLE_KERNEL_VANILLA_STABLE:-true}"; then
    UPDATE_KERNEL_TARGET=none
    UPDATE_KERNEL_PREVIOUS="$(uname -r)"
    return 0
  fi
  UPDATE_KERNEL_PREVIOUS="$(kernel_lifecycle_latest_installed)"
  local rc=0
  UPDATE_KERNEL_TARGET="$(kernel_lifecycle_prepare_rolling_update)" || rc=$?
  if ((rc == EXIT_KERNEL_DEFERRED)) && is_true "${KERNEL_DEFER_WHEN_UNAVAILABLE:-true}"; then
    # A lagging RPM or an unreachable kernel.org must never hold back the
    # security updates of every other package: the kernel alone is deferred,
    # excluded from the transaction and stays on the running N.
    UPDATE_KERNEL_TARGET=none
    UPDATE_KERNEL_DEFERRED=true
    ui_check WARN 'Kernel update' "deferred: upstream kernel not verifiable or not packaged yet; current N=${UPDATE_KERNEL_PREVIOUS:-unknown} kept; rerun the update later"
    return 0
  fi
  ((rc == 0)) || return "$rc"
  kernel_lifecycle_pin_target "$UPDATE_KERNEL_TARGET" || return $?
  ui_check PASS 'Kernel update target' "N=$UPDATE_KERNEL_TARGET; current=${UPDATE_KERNEL_PREVIOUS:-none}; retention=$(kernel_lifecycle_max_installed)"
}

prepare_dnf_offline() {
  local mode="$1"
  local steam_repo_flag=''
  require_dnf5
  if [[ -s "$UPDATE_STATE_FILE" && "$(update_state_value phase)" =~ ^(prepared|reboot-requested)$ ]]; then
    ui_error 'A project-owned offline update is already pending; finalize it before preparing another one'
    exit "$EXIT_SECURITY_BLOCK"
  fi
  ui_banner 'FEDORA WORKSTATION UPDATE' 'PREPARE DNF5 OFFLINE TRANSACTION'
  # Resolve all required package sources before pinning a kernel target or
  # creating a DNF5 transaction: a missing Gaming repository must fail early.
  steam_repo_flag="$(update_steam_repository_flag)" || return $?
  prepare_kernel_rolling_target || exit $?
  UPDATE_SOURCE_BOOT_ID="$(update_current_boot_id)"
  UPDATE_TRANSACTION_COMMENT="fgc-offline-$(python3 -c 'import uuid; print(uuid.uuid4())')"
  UPDATE_PREPARED_TIMESTAMP="$(date +%s)"
  local -a kernel_exclusion=()
  if is_true "$UPDATE_KERNEL_DEFERRED"; then
    kernel_exclusion=(--exclude="$(kernel_lifecycle_managed_packages_csv)")
  fi
  local -a steam_repo_args=()
  [[ -z "$steam_repo_flag" ]] || steam_repo_args=("$steam_repo_flag")
  sudo dnf5 --refresh upgrade --offline -y --comment="$UPDATE_TRANSACTION_COMMENT" "${kernel_exclusion[@]}" "${steam_repo_args[@]}"
  if ! sudo test -e /usr/lib/sysimage/libdnf5/offline/transaction.json; then
    UPDATE_REBOOT_REQUIRED=false
    if [[ "$mode" == full ]]; then
      complete_update "$mode" no-offline
      return $?
    fi
    write_update_state no-transaction "$mode" not-run
    ui_summary 'NO OFFLINE TRANSACTION PREPARED' 'NO STAGED DNF5 REQUEST; NO REBOOT OR OFFLINE COMPLETION TO CERTIFY' "$UPDATE_STATE_FILE" "$LOG_DIR"
    return 0
  fi
  sudo dnf5 offline status
  UPDATE_REBOOT_REQUIRED=true
  write_update_state prepared "$mode" pending
  if is_true "$UPDATE_KERNEL_DEFERRED"; then
    ui_summary 'OFFLINE UPDATE PREPARED (KERNEL DEFERRED)' "ALL PACKAGES EXCEPT THE KERNEL; RUNNING KERNEL KEPT; NEXT: ./control.sh update reboot" "$UPDATE_STATE_FILE" "$LOG_DIR"
  else
    ui_summary 'OFFLINE UPDATE PREPARED' "LATEST STABLE KERNEL TARGET=${UPDATE_KERNEL_TARGET}; MAX TWO KERNELS; NEXT: ./control.sh update reboot" "$UPDATE_STATE_FILE" "$LOG_DIR"
  fi
}

request_offline_reboot() {
  require_dnf5
  require_current_update_state || exit $?
  local mode
  mode="$(update_state_value mode)"
  UPDATE_KERNEL_TARGET="$(update_state_value kernel_target)"
  UPDATE_KERNEL_PREVIOUS="$(update_state_value kernel_previous)"
  UPDATE_KERNEL_DEFERRED="$(update_state_value kernel_deferred)"
  [[ "$UPDATE_KERNEL_DEFERRED" == true ]] || UPDATE_KERNEL_DEFERRED=false
  sudo dnf5 offline status >/dev/null
  UPDATE_REBOOT_REQUIRED=true
  write_update_state reboot-requested "$mode" pending
  ui_check WARN 'DNF5 offline reboot' 'system will reboot into the minimal offline transaction now; latest stable kernel becomes the normal default'
  sudo dnf5 offline reboot
}

apply_flatpak() {
  if command_exists flatpak; then
    ui_banner 'FEDORA WORKSTATION UPDATE' 'FLATPAK APPLICATIONS'
    flatpak update -y || return $?
    ui_check PASS 'Flatpak applications' 'update transaction completed'
  else
    ui_check EXPECTED 'Flatpak applications' 'flatpak unavailable'
  fi
}

capture_offline_log() {
  local report="$REPORT_ROOT/$RUN_ID-dnf5-offline-last.log"
  if ! sudo dnf5 offline log --number=-1 2>&1 | tee "$report" >/dev/null; then
    ui_error "Unable to read latest DNF5 offline log: $report"
    return "$EXIT_POSTCHECK_FAILED"
  fi
  ui_check PASS 'DNF5 offline log' "$report"
}

require_applied_offline_transaction() {
  local source_boot timestamp comment history current_boot
  source_boot="$(update_state_value source_boot_id)"
  timestamp="$(update_state_value prepared_timestamp)"
  comment="$(update_state_value transaction_comment)"
  current_boot="$(update_current_boot_id)" || return "$EXIT_PRECHECK_FAILED"
  [[ "$current_boot" =~ ^[0-9a-f-]{36}$ && "$source_boot" =~ ^[0-9a-f-]{36}$ && "$timestamp" =~ ^[0-9]+$ &&
     "$current_boot" != "$source_boot" ]] || {
    ui_error 'No new normal boot since offline preparation; completion is unproven.'
    return "$EXIT_PRECHECK_FAILED"
  }
  # A prepared request survives a normal reboot that never ran the offline
  # service. A readable old journal cannot stand in for the exact transaction.
  if sudo test -e /usr/lib/sysimage/libdnf5/offline/transaction.json; then
    ui_error 'A DNF5 offline transaction is still staged; completion is unproven.'
    return "$EXIT_PRECHECK_FAILED"
  fi
  history="$(sudo dnf5 history info 1..last --json)" || return "$EXIT_POSTCHECK_FAILED"
  python3 "$REPO_ROOT/scripts/maintenance/verify-offline-history.py" "$comment" "$timestamp" <<<"$history" >/dev/null || {
    ui_error 'The successful DNF5 history entry does not match the prepared transaction.'
    return "$EXIT_POSTCHECK_FAILED"
  }
}

complete_update() {
  local mode="$1" transaction="${2:-offline}" doctor_rc=0 flatpak_rc=0 firmware_rc=0
  UPDATE_REBOOT_REQUIRED=false
  if [[ "$mode" == full ]]; then
    apply_flatpak || flatpak_rc=$?
    if (( flatpak_rc != 0 )); then
      write_update_state failed "$mode" "$flatpak_rc"
      ui_error "Flatpak update failed rc=$flatpak_rc"
      return "$flatpak_rc"
    fi
  fi
  # The firmware consultation is advisory to the RPM/Flatpak transaction.
  # Keep a successful package update distinct from an unverified firmware state.
  check_firmware || firmware_rc=$?

  if "$REPO_ROOT/diagnostic.sh"; then
    ui_check PASS 'Post-update diagnostic' 'global doctor completed'
  else
    doctor_rc=$?
    ui_check KO 'Post-update diagnostic' "doctor rc=$doctor_rc"
  fi

  if ((doctor_rc == 0)); then
    write_update_state completed "$mode" 0
    if ((firmware_rc != 0)) && is_true "$UPDATE_KERNEL_DEFERRED"; then
      ui_summary 'MISE À JOUR LOGICIELLE TERMINÉE — NOYAU REPORTÉ, FIRMWARE NON VÉRIFIÉ' 'RPM/FLATPAK ET DIAGNOSTIC VALIDÉS ; NOYAU À RECHERCHER PLUS TARD ; CONTRÔLER SÉPARÉMENT ./control.sh update firmware' "$UPDATE_STATE_FILE" "$LOG_DIR"
    elif ((firmware_rc != 0)); then
      ui_summary 'MISE À JOUR LOGICIELLE TERMINÉE — FIRMWARE NON VÉRIFIÉ' 'RPM/FLATPAK ET DIAGNOSTIC VALIDÉS ; CONSULTER ./control.sh update firmware AVANT DE CONCLURE SUR LE MATÉRIEL' "$UPDATE_STATE_FILE" "$LOG_DIR"
    elif is_true "$UPDATE_KERNEL_DEFERRED"; then
      ui_summary 'UPDATE COMPLETED (KERNEL DEFERRED)' 'ALL OTHER PACKAGES UPDATED + POSTCHECK PASS; KERNEL STILL PENDING UPSTREAM PACKAGING: RERUN ./control.sh update LATER' "$UPDATE_STATE_FILE" "$LOG_DIR"
    elif [[ "$transaction" == no-offline ]]; then
      ui_summary 'UPDATE COMPLETED' 'RPM PACKAGES ALREADY CURRENT; FLATPAK + POSTCHECK PASS; NO OFFLINE REBOOT REQUIRED' "$UPDATE_STATE_FILE" "$LOG_DIR"
    else
      ui_summary 'UPDATE COMPLETED' 'LATEST STABLE KERNEL RUNNING + N/N-1 RETENTION + POSTCHECK PASS; GOLDEN RECERTIFICATION MAY NOW BE REQUIRED' "$UPDATE_STATE_FILE" "$LOG_DIR"
    fi
  else
    write_update_state failed "$mode" "$doctor_rc"
    ui_summary 'UPDATE POSTCHECK FAILED' 'INSPECT UPDATE LOGS AND DIAGNOSTICS BEFORE CONTINUING' "$UPDATE_STATE_FILE" "$LOG_DIR"
    return "$EXIT_POSTCHECK_FAILED"
  fi
}

finalize_offline_update() {
  require_dnf5
  require_current_update_state || exit $?
  local mode kernel_rc=0
  mode="$(update_state_value mode)"
  UPDATE_KERNEL_TARGET="$(update_state_value kernel_target)"
  UPDATE_KERNEL_PREVIOUS="$(update_state_value kernel_previous)"
  UPDATE_KERNEL_DEFERRED="$(update_state_value kernel_deferred)"
  [[ "$UPDATE_KERNEL_DEFERRED" == true ]] || UPDATE_KERNEL_DEFERRED=false
  ui_banner 'FEDORA WORKSTATION UPDATE' 'POST-OFFLINE VALIDATION'

  require_applied_offline_transaction || return $?
  capture_offline_log || exit $?
  sudo dnf5 check || { ui_error 'DNF5 packagedb/dependency validation failed after offline transaction'; write_update_state failed "$mode" 1; exit "$EXIT_POSTCHECK_FAILED"; }
  ui_check PASS 'DNF5 packagedb' 'dependency/database check PASS'

  if is_true "${ENABLE_KERNEL_VANILLA_STABLE:-true}"; then
    kernel_lifecycle_finalize_update "$UPDATE_KERNEL_TARGET" || kernel_rc=$?
    if ((kernel_rc != 0)); then
      if ((kernel_rc == EXIT_PRECHECK_FAILED)); then
        ui_summary 'KERNEL REBOOT REQUIRED' 'NEW KERNEL IS INSTALLED; BOOT IT ONCE THEN RERUN ./control.sh update finalize' "$UPDATE_STATE_FILE" "$LOG_DIR"
        return "$kernel_rc"
      fi
      write_update_state failed "$mode" "$kernel_rc"
      return "$kernel_rc"
    fi
    UPDATE_KERNEL_PREVIOUS="$(kernel_lifecycle_previous_installed)"
  fi

  complete_update "$mode" offline
}

mode="${1:---check}"
case "$mode" in
  -h|--help) usage; exit 0 ;;
esac

require_fedora

case "$mode" in
  --check)
    ui_banner 'FEDORA WORKSTATION UPDATE' 'READ-ONLY UPDATE OVERVIEW'
    check_updates_overview
    ;;
  --apply)
    require_baremetal_update; mandatory_preupdate_backup; prepare_dnf_offline full
    ;;
  --dnf-only)
    require_baremetal_update; mandatory_preupdate_backup; prepare_dnf_offline dnf-only
    ;;
  --offline-reboot)
    require_baremetal_update; request_offline_reboot
    ;;
  --finalize)
    require_baremetal_update; finalize_offline_update
    ;;
  --offline-status)
    show_offline_status
    ;;
  --offline-log)
    require_dnf5; sudo dnf5 offline log --number=-1
    ;;
  --flatpak-only)
    require_baremetal_update; apply_flatpak
    ;;
  --firmware-check)
    check_firmware
    ;;
  --scope)
    check_update_scope
    ;;
  *) usage >&2; exit "$EXIT_USAGE" ;;
esac

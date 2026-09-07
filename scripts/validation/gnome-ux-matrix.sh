#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
source "$REPO_ROOT/lib/validation_gates.sh"
scope="${1:-status}"
case "$scope" in gate2|gate3|status) ;; *) echo 'Usage: gnome-ux-matrix.sh [gate2|gate3|status]' >&2; exit "$EXIT_USAGE";; esac
suspend_count(){ local f c=0 fp; fp="$(workstation_runtime_fingerprint)"; shopt -s nullglob; for f in "$STATE_ROOT/final/evidence"/suspend-*.ok; do if grep -Fxq "fingerprint=$fp" "$f"; then ((c+=1)); fi; done; shopt -u nullglob; printf '%d\n' "$c"; }
gate2_marker="$STATE_ROOT/validation/gnome-ux-gate2-$(repo_commit).ok"; gate3_marker="$STATE_ROOT/final/evidence/gnome-ux.ok"
marker_valid(){ local f="$1"; [[ -s "$f" ]] || return 1; grep -Fxq 'status=PASS' "$f" || return 1; grep -Fxq "effective_config_sha256=$(effective_config_sha256)" "$f" || return 1; if [[ "$f" == "$gate3_marker" ]]; then grep -Fxq "workstation_fingerprint=$(workstation_runtime_fingerprint)" "$f"; else grep -Fxq "commit=$(repo_commit)" "$f"; fi; }
if [[ "$scope" == status ]]; then
  if marker_valid "$gate2_marker"; then ui_check OK 'Gate 2 GNOME UX' "$gate2_marker"; else ui_check WARN 'Gate 2 GNOME UX' missing/stale; fi
  if marker_valid "$gate3_marker"; then ui_check OK 'Gate 3 GNOME UX' "$gate3_marker"; else ui_check WARN 'Gate 3 GNOME UX' missing/stale; fi
  exit 0
fi
if [[ ! -t 0 || ! -t 1 ]]; then ui_error 'GNOME UX matrix requires an interactive terminal'; exit "$EXIT_SECURITY_BLOCK"; fi
if [[ "${XDG_CURRENT_DESKTOP:-}" != *GNOME* || "${XDG_SESSION_TYPE:-}" != wayland ]]; then ui_error 'GNOME/Wayland session required'; exit "$EXIT_PRECHECK_FAILED"; fi
if [[ "$scope" == gate2 ]]; then
  runtime_is_virtualbox || { ui_error 'Gate 2 UX matrix requires Oracle VirtualBox'; exit "$EXIT_SECURITY_BLOCK"; }
  validation_require_imported_gate 1 || { ui_error 'Import matching Gate 1 proof first'; exit "$EXIT_PRECHECK_FAILED"; }
else
  runtime_is_baremetal || { ui_error 'Gate 3 UX matrix is bare-metal only'; exit "$EXIT_SECURITY_BLOCK"; }
  validation_require_chain || { ui_error 'Gate 3 UX matrix requires imported Gate 1 → Gate 2 chain'; exit "$EXIT_PRECHECK_FAILED"; }
  cycles="$(suspend_count)"; if (( cycles < ${FINAL_CERT_MIN_SUSPEND_CYCLES:-5} )); then ui_error "Run ${FINAL_CERT_MIN_SUSPEND_CYCLES:-5} suspend/resume cycles first; current=$cycles"; exit "$EXIT_PRECHECK_FAILED"; fi
fi
"$REPO_ROOT/diagnostics/gnome-desktop-integration-doctor" --quiet --functional --preflight
if [[ "$scope" == gate2 ]]; then "$REPO_ROOT/diagnostics/portal-functional-doctor" --interactive --gate2; else "$REPO_ROOT/diagnostics/portal-functional-doctor" --interactive --gate3; if is_true "${ENABLE_KVM:-true}"; then "$REPO_ROOT/diagnostics/nautilus-vm-live-doctor" --certify; fi; fi
probe_dir="$HOME/FGC Ptyxis CWD Test"; mkdir -p "$probe_dir"; nautilus --new-window "$probe_dir" >/dev/null 2>&1 &
cleanup(){ rm -rf -- "$probe_dir"; }; trap cleanup EXIT
ask(){ local label="$1" answer; printf '\n[%s]\nTapez PASS uniquement après vérification visuelle : ' "$label"; read -r answer; if [[ "$answer" != PASS ]]; then ui_error "Visual check refused: $label"; exit "$EXIT_PRECHECK_FAILED"; fi; ui_check OK "$label" PASS; }
ask "GNOME Overview : ouverture fluide, aucune corruption graphique ni bannière d’erreur"
ask 'Dock : ordre Golden correct, lancement et focus des favoris cohérents'
ask 'DING : contenu réel de ~/Bureau visible, Corbeille visible, pas de volumes parasites'
ask 'Show Desktop Plus : bouton et Super+D masquent/restaurent correctement les fenêtres'
ask 'Resource Monitor : CPU/RAM/réseau lisibles; télémétrie physique attendue seulement en Gate 3'
ask 'Nautilus : navigation, previews/Sushi, archives et recherche de fichiers fonctionnent'
printf '\nDans la fenêtre Nautilus ouverte sur "%s", utilisez clic droit → Open in Console, puis exécutez pwd.\n' "$probe_dir"
ask 'Nautilus → Ptyxis : Open in Console ouvre Ptyxis exactement dans le dossier avec espaces'
ask 'Applications par défaut : Files/Papers/Loupe/Text Editor/Showtime/File Roller ouvrent les types prévus'
if [[ "$scope" == gate3 ]]; then ask 'Après les cycles suspend/resume : GNOME Shell, dock, DING, Ptyxis et Nautilus restent stables'; if is_true "${ENABLE_KVM:-true}"; then ask 'Nautilus : bookmarks Ubuntu DevOps SFTP et Windows VM SMB sont visibles et ouvrables'; fi; fi
if [[ "$scope" == gate2 ]]; then
  mkdir -p "$(dirname "$gate2_marker")"; { printf 'schema=1\nstatus=PASS\ncommit=%s\neffective_config_sha256=%s\nportal_functional=PASS\nnautilus_ptyxis=PASS\nlocalsearch=PASS\nmanual_visual=PASS\nutc=%s\n' "$(repo_commit)" "$(effective_config_sha256)" "$(date -u +%FT%TZ)"; } | evidence_atomic_write "$gate2_marker" 0600; ui_check OK 'Gate 2 GNOME UX evidence' "$gate2_marker"
else
  if is_true "${ENABLE_KVM:-true}"; then vm_state=PASS; else vm_state=N/A; fi
  mkdir -p "$(dirname "$gate3_marker")"; { printf 'schema=1\nstatus=PASS\nworkstation_fingerprint=%s\neffective_config_sha256=%s\nportal_functional=PASS\nnautilus_ptyxis=PASS\nlocalsearch=PASS\nnautilus_vm_live=%s\nsuspend_cycles=%s\nmanual_visual=PASS\nutc=%s\n' "$(workstation_runtime_fingerprint)" "$(effective_config_sha256)" "$vm_state" "$(suspend_count)" "$(date -u +%FT%TZ)"; } | evidence_atomic_write "$gate3_marker" 0600; ui_check OK 'Gate 3 GNOME UX evidence' "$gate3_marker"
fi

#!/usr/bin/env bash
# Persistent, per-user incident guard. Call mutators only under install_lock.
# No trap clears this record: kill, failure and unexpected exits leave it open.
apply_incident_root() {
  printf '%s/fedora-gnome-custom/apply-incidents\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
}
apply_incident_active() { printf '%s/active.marker\n' "$(apply_incident_root)"; }
apply_incident_require_clear() {
  local root active
  root="$(apply_incident_root)"
  active="$(apply_incident_active)"
  if [[ -L "$root" || ( -e "$root" && ( ! -d "$root" || ! -r "$root" || ! -x "$root" ) ) ||
        -e "$active" || -L "$active" ]]; then
    printf 'APPLY incident pending or inaccessible: %s; inspect scripts/validation/apply-incident.sh status and TROUBLESHOOTING.md\n' "$active" >&2
    return 50
  fi
}
apply_incident_begin() {
  local root active marker="$STATE_ROOT/preapply-backup.ok" digest
  apply_incident_require_clear || return $?
  [[ "$RUN_ID" =~ ^[A-Za-z0-9_.-]+$ && "$RUN_ID" != . && "$RUN_ID" != .. ]] || return 50
  [[ -f "$marker" && ! -L "$marker" ]] || return 50
  # Recheck the exact Borg point after human confirmation, before mutations.
  apply_gate_require_backup || return 50
  root="$(apply_incident_root)"
  active="$(apply_incident_active)"
  (umask 077; mkdir -p "$root/history") || return 50
  [[ ! -L "$root" && ! -L "$root/history" ]] || return 50
  digest="$(evidence_file_sha256 "$marker")" || return 50
  [[ "$digest" =~ ^[0-9a-f]{64}$ ]] || return 50
  {
    printf 'incident_run_id=%s\nincident_repo_root=%s\nincident_started_utc=%s\noriginal_marker_sha256=%s\n' \
      "$RUN_ID" "$REPO_ROOT" "$(date -u +%FT%TZ)" "$digest"
    cat -- "$marker"
  } | evidence_atomic_write "$active" 0600 || return 50
  # Flush the filesystem before entering the first real module.
  sync -f "$active" || return 50
}
apply_incident_close() {
  local resolution="$1" root active run destination
  case "$resolution" in completed|operator-reviewed) ;; *) return 50;; esac
  root="$(apply_incident_root)"
  active="$(apply_incident_active)"
  [[ -d "$root/history" && ! -L "$root" && ! -L "$root/history" &&
     -f "$active" && ! -L "$active" && -s "$active" ]] || return 50
  run="$(evidence_marker_value "$active" incident_run_id)" || return 50
  [[ "$run" =~ ^[A-Za-z0-9_.-]+$ && "$run" != . && "$run" != .. ]] || return 50
  if [[ "$resolution" == completed ]]; then [[ "$run" == "$RUN_ID" ]] || return 50; fi
  destination="$root/history/$run.marker"
  # If interrupted after history publication, preserve the active record and
  # refuse rather than overwrite the original history. Manual inspection needed.
  [[ ! -e "$destination" && ! -L "$destination" ]] || return 50
  {
    cat -- "$active" || return 50
    printf 'incident_resolution=%s\nincident_closed_utc=%s\n' "$resolution" "$(date -u +%FT%TZ)"
  } | evidence_atomic_write "$destination" 0600 || return 50
  sync -f "$destination" || return 50
  rm -- "$active" || return 50
  sync -f "$root" || return 50
}

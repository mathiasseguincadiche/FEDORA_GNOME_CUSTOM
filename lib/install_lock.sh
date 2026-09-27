#!/usr/bin/env bash

# One lock per user, shared by all repository clones. Acquire before logging_init
# so simultaneous runs cannot truncate logs or overwrite certification reports.
# Every mutating entrypoint (install, update, kernel lifecycle, backups) takes
# it. A child started by the lock holder (e.g. update-system -> backup-now)
# inherits FGC_INSTALL_LOCK_OWNER and does not try to lock twice.
# True when PID $1 is the current shell or one of its ancestors.
install_lock_is_ancestor() {
  local owner="$1" pid="$BASHPID" stat
  [[ "$owner" =~ ^[0-9]+$ ]] || return 1
  while [[ "$pid" =~ ^[0-9]+$ ]] && (( pid > 1 )); do
    [[ "$pid" == "$owner" ]] && return 0
    stat="$(cat "/proc/$pid/stat" 2>/dev/null)" || return 1
    stat="${stat##*) }"          # drop "pid (comm) " (comm may contain spaces)
    pid="$(awk '{print $2}' <<<"$stat")"   # field 4 of stat = PPID
  done
  return 1
}

install_lock_acquire() {
  local root="${XDG_RUNTIME_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/fedora-gnome-custom}"
  # Re-entry is only granted to real descendants of the lock holder: a copied
  # or forged FGC_INSTALL_LOCK_OWNER from an unrelated process is ignored.
  if [[ -n "${FGC_INSTALL_LOCK_OWNER:-}" ]] && install_lock_is_ancestor "$FGC_INSTALL_LOCK_OWNER"; then
    return 0
  fi
  command -v flock >/dev/null 2>&1 || { echo 'flock is required for installation locking.' >&2; return 50; }
  (umask 077; mkdir -p "$root") || return 50
  exec {FGC_INSTALL_LOCK_FD}>"$root/fedora-gnome-custom-install.lock" || return 50
  flock -n "$FGC_INSTALL_LOCK_FD" || {
    echo 'Another installation/update/backup is running for this user.' >&2
    return 50
  }
  FGC_INSTALL_LOCK_OWNER=$$
  export FGC_INSTALL_LOCK_OWNER
}

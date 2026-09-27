#!/usr/bin/env bash

# One lock per user, shared by all repository clones. Acquire before logging_init
# so simultaneous runs cannot truncate logs or overwrite certification reports.
install_lock_acquire() {
  local root="${XDG_RUNTIME_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/fedora-gnome-custom}"
  command -v flock >/dev/null 2>&1 || { echo 'flock is required for installation locking.' >&2; return 50; }
  (umask 077; mkdir -p "$root") || return 50
  exec {FGC_INSTALL_LOCK_FD}>"$root/fedora-gnome-custom-install.lock" || return 50
  flock -n "$FGC_INSTALL_LOCK_FD" || {
    echo 'Another installation/preflight is running for this user.' >&2
    return 50
  }
}

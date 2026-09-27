#!/usr/bin/env bash
# shellcheck disable=SC2016  # single-quoted scripts are passed to child bash on purpose
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export XDG_RUNTIME_DIR="$tmp"
source "$ROOT/lib/install_lock.sh"
install_lock_acquire
# This test process now holds the lock and exports FGC_INSTALL_LOCK_OWNER.
# A second, *independent* run (no inherited owner) must be refused.
rc=0
env -u FGC_INSTALL_LOCK_OWNER bash -c 'source "$1/lib/install_lock.sh"; install_lock_acquire' bash "$ROOT" || rc=$?
[[ "$rc" == 50 ]]
flock -u "$FGC_INSTALL_LOCK_FD"
unset FGC_INSTALL_LOCK_OWNER
bash -c 'source "$1/lib/install_lock.sh"; install_lock_acquire' bash "$ROOT"

# A child of the lock holder (update-system -> backup-now) is not blocked...
bash -c 'source "$1/lib/install_lock.sh"; install_lock_acquire; bash -c "source \"\$1/lib/install_lock.sh\"; install_lock_acquire" bash "$1"' bash "$ROOT"
# ...but an unrelated process that merely copies a dead owner PID is.
bash -c 'source "$1/lib/install_lock.sh"; install_lock_acquire; sleep 2' bash "$ROOT" &
holder=$!
sleep 0.5
rc=0
FGC_INSTALL_LOCK_OWNER=999999 bash -c 'source "$1/lib/install_lock.sh"; install_lock_acquire' bash "$ROOT" || rc=$?
[[ "$rc" == 50 ]]
# ...and neither is a process that forges the PID of a live, unrelated holder.
rc=0
FGC_INSTALL_LOCK_OWNER="$holder" setsid bash -c 'source "$1/lib/install_lock.sh"; install_lock_acquire' bash "$ROOT" || rc=$?
[[ "$rc" == 50 ]]
wait "$holder"

# Every mutating entrypoint takes the lock; read-only kernel status does not.
for entry in install.sh scripts/maintenance/update-system.sh prepare-preapply-backup.sh scripts/backup/backup-now.sh scripts/kernel/kernel-lifecycle.sh; do
  grep -Fq 'install_lock_acquire' "$ROOT/$entry"
done
grep -Fq 'if [[ "${1:-status}" != status ]]; then install_lock_acquire' "$ROOT/scripts/kernel/kernel-lifecycle.sh"
echo 'install lock behavior: PASS'

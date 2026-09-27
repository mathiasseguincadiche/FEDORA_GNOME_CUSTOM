#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export XDG_RUNTIME_DIR="$tmp"
source "$ROOT/lib/install_lock.sh"
install_lock_acquire
rc=0
bash -c 'source "$1/lib/install_lock.sh"; install_lock_acquire' bash "$ROOT" || rc=$?
[[ "$rc" == 50 ]]
flock -u "$FGC_INSTALL_LOCK_FD"
bash -c 'source "$1/lib/install_lock.sh"; install_lock_acquire' bash "$ROOT"
echo 'install lock behavior: PASS'

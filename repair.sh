#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1:-help}" in
 display)
   exec "$HOME/.local/libexec/fedora-gnome-display-repair"
   ;;
 kernel-status)
   exec "$REPO_ROOT/diagnostics/kernel-doctor"
   ;;
 kernel-rollback)
   exec "$REPO_ROOT/scripts/kernel/rollback-to-fedora.sh"
   ;;
 coldstart)
   exec "$REPO_ROOT/diagnostics/nautilus-coldstart-doctor"
   ;;
 help|*)
   cat <<EOF
Diagnosis-first recovery:
  $0 display          Reapply the certified GNOME display link/mode
  $0 coldstart        Measure a true Nautilus first-click cold launch
  $0 kernel-status    Validate current kernel + Arc B580/xe
  $0 kernel-rollback  Return packages to Fedora kernel repositories

Diagnostics:
  $REPO_ROOT/diagnostic.sh
  $REPO_ROOT/diagnostics/display-doctor
  $REPO_ROOT/diagnostics/suspend-doctor
  $REPO_ROOT/scripts/collect-boot-failure.sh
EOF
   ;;
esac

#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while true; do
  cat <<'EOF'

FEDORA GNOME CUSTOM
1) Diagnostic global
2) Dry-run complet
3) Préparer backup pré-APPLY
4) APPLY réel protégé
5) Graphics doctor
6) Suspend/resume doctor
7) Storage doctor
8) GNOME doctor
0) Quitter
EOF
  read -rp 'Choix: ' choice
  case "$choice" in
    1) "$REPO_ROOT/diagnostic.sh" ;;
    2) "$REPO_ROOT/install.sh" --dry-run ;;
    3) "$REPO_ROOT/prepare-preapply-backup.sh" ;;
    4) "$REPO_ROOT/install.sh" --apply ;;
    5) "$REPO_ROOT/diagnostics/graphics-doctor" ;;
    6) "$REPO_ROOT/diagnostics/suspend-doctor" ;;
    7) "$REPO_ROOT/diagnostics/storage-doctor" ;;
    8) "$REPO_ROOT/diagnostics/gnome-doctor" ;;
    0) exit 0 ;;
    *) echo 'Choix invalide.' ;;
  esac
done

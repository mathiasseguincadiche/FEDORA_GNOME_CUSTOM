#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
while true; do
  cat <<'EOF'

FEDORA GNOME CUSTOM
1) Diagnostic global
2) Hardware baseline status
3) Hardware baseline snapshot
4) Dry-run complet
5) Préparer backup pré-APPLY
6) APPLY réel protégé
7) Graphics doctor
8) Suspend/resume doctor
9) Storage doctor
10) GNOME doctor
11) Applications GTK4 doctor
12) Multimedia / codecs doctor
0) Quitter
EOF
  read -rp 'Choix: ' choice
  case "$choice" in
    1) "$REPO_ROOT/diagnostic.sh" ;;
    2) bash "$REPO_ROOT/diagnostics/baseline-doctor" status ;;
    3) bash "$REPO_ROOT/diagnostics/baseline-doctor" snapshot ;;
    4) "$REPO_ROOT/install.sh" --dry-run ;;
    5) "$REPO_ROOT/prepare-preapply-backup.sh" ;;
    6) "$REPO_ROOT/install.sh" --apply ;;
    7) "$REPO_ROOT/diagnostics/graphics-doctor" ;;
    8) "$REPO_ROOT/diagnostics/suspend-doctor" ;;
    9) "$REPO_ROOT/diagnostics/storage-doctor" ;;
    10) "$REPO_ROOT/diagnostics/gnome-doctor" ;;
    11) bash "$REPO_ROOT/diagnostics/applications-doctor" ;;
    12) bash "$REPO_ROOT/diagnostics/media-doctor" ;;
    0) exit 0 ;;
    *) echo 'Choix invalide.' ;;
  esac
done

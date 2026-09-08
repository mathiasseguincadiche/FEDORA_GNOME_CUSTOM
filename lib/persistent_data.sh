#!/usr/bin/env bash
# Persistent user-data layout on the dedicated second T705.

persistent_data_mount() { printf '%s\n' '/data'; }
persistent_data_documents() { printf '%s/Documents\n' "$(persistent_data_mount)"; }
persistent_data_projects() { printf '%s/Projets\n' "$(persistent_data_mount)"; }
persistent_data_iso() { printf '%s/ISO\n' "$(persistent_data_mount)"; }
persistent_data_games() { printf '%s/Jeux\n' "$(persistent_data_mount)"; }

persistent_data_owner_user() {
  local candidate=''
  if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != root ]]; then
    candidate="$SUDO_USER"
  elif (( EUID != 0 )); then
    candidate="$(id -un)"
  elif [[ -n "${USER:-}" && "${USER}" != root ]]; then
    candidate="$USER"
  elif [[ -n "${REPO_ROOT:-}" ]]; then
    candidate="$(stat -c '%U' "$REPO_ROOT" 2>/dev/null || true)"
  fi
  [[ -n "$candidate" && "$candidate" != root ]] || return 1
  id "$candidate" >/dev/null 2>&1 || return 1
  printf '%s\n' "$candidate"
}

persistent_data_validate_mount() {
  local mount target fstype root_source data_source
  mount="$(persistent_data_mount)"
  target="$(findmnt -n -T "$mount" -o TARGET 2>/dev/null || true)"
  fstype="$(findmnt -n -T "$mount" -o FSTYPE 2>/dev/null || true)"
  root_source="$(findmnt -n -T / -o SOURCE 2>/dev/null || true)"
  data_source="$(findmnt -n -T "$mount" -o SOURCE 2>/dev/null || true)"
  [[ "$target" == "$mount" ]] || return 1
  [[ "$fstype" == ext4 ]] || return 1
  [[ -n "$data_source" && "$data_source" != "$root_source" ]] || return 1
}

persistent_data_path_allowed_for_daily_backup() {
  case "$1" in
    /data/Documents|/data/Projets) return 0 ;;
    *) return 1 ;;
  esac
}

persistent_data_layout_paths() {
  persistent_data_documents
  persistent_data_projects
  persistent_data_iso
  persistent_data_games
}

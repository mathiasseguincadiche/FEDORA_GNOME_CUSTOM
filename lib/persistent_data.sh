#!/usr/bin/env bash
# Persistent user-data layout on the dedicated second T705.
PERSISTENT_DATA_HELPER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/persistent_data_identity.py"

persistent_data_mount() { printf '%s\n' '/data'; }
persistent_data_documents() { printf '%s/Documents\n' "$(persistent_data_mount)"; }
persistent_data_projects() { printf '%s/Projets\n' "$(persistent_data_mount)"; }
persistent_data_iso() { printf '%s/ISO\n' "$(persistent_data_mount)"; }
persistent_data_games() { printf '%s/Jeux\n' "$(persistent_data_mount)"; }
persistent_data_ai() { printf '%s/IA\n' "$(persistent_data_mount)"; }
persistent_data_openclaw() { printf '%s/Openclaw\n' "$(persistent_data_ai)"; }
persistent_data_identity_path() { printf '%s\n' "${PERSISTENT_DATA_IDENTITY_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/fedora-gnome-custom/data-storage-identity.json}"; }
persistent_data_probe() { python3 "$PERSISTENT_DATA_HELPER" probe --model "${EXPECTED_NVME_MODEL:-CT1000T705SSD3}"; }
persistent_data_enroll() { python3 "$PERSISTENT_DATA_HELPER" enroll --model "${EXPECTED_NVME_MODEL:-CT1000T705SSD3}" --identity "$(persistent_data_identity_path)" --confirm-serial "$1"; }

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
  [[ "${1:-/data}" == /data ]] || return 1
  python3 "$PERSISTENT_DATA_HELPER" validate --model "${EXPECTED_NVME_MODEL:-CT1000T705SSD3}" --identity "$(persistent_data_identity_path)" >/dev/null
}

persistent_data_path_allowed_for_daily_backup() {
  case "$1" in
    /data/Documents|/data/Projets|/data/IA/Openclaw) return 0 ;;
    *) return 1 ;;
  esac
}

persistent_data_validate_user_path() {
  local path="$1"
  persistent_data_path_allowed_for_daily_backup "$path" || return 1
  [[ ! -L "$path" && "$(readlink -m -- "$path")" == "$path" ]]
}

persistent_data_layout_paths() {
  persistent_data_documents
  persistent_data_projects
  persistent_data_iso
  persistent_data_games
  persistent_data_ai
  persistent_data_openclaw
}

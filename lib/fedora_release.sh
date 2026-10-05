#!/usr/bin/env bash
# Selected release contract; Fedora 45 requires a reviewed promoted profile.
fedora_actual_release() {
  local os_file="${FEDORA_OS_RELEASE_FILE:-/etc/os-release}"
  [[ -r "$os_file" ]] || return 1
  grep -Eq '^ID="?fedora"?$' "$os_file" || return 1
  awk -F= '$1=="VERSION_ID" {gsub(/"/,"",$2); print $2; exit}' "$os_file"
}
fedora_expected_gnome_major() {
  case "${HOST_RELEASE:-44}" in 44) printf '50\n' ;; 45) printf '51\n' ;; *) return 1 ;; esac
}
fedora_require_profile() {
  local release="${1:-${HOST_RELEASE:-44}}"
  case "$release" in
    44) return 0 ;;
    45) python3 "$REPO_ROOT/scripts/development/fedora-profile.py" validate "$REPO_ROOT" 45 ;;
    *) return 1 ;;
  esac
}
fedora_require_selected() {
  fedora_require_profile || return 1
  [[ "$(fedora_actual_release)" == "${HOST_RELEASE:-44}" ]]
}
fedora_shell_matches() {
  local major
  major="$(fedora_expected_gnome_major)" || return 1
  [[ "$1" =~ ^GNOME[[:space:]]Shell[[:space:]]([0-9]+)([.]|$) &&
     "${BASH_REMATCH[1]}" == "$major" ]]
}
fedora_load_profile_extensions() {
  [[ "${HOST_RELEASE:-44}" != 45 ]] || {
    fedora_require_profile 45 || return 60
    # The Python validator checks the SHA and assignment grammar before sourcing.
    # shellcheck disable=SC1091
    source "$REPO_ROOT/profiles/fedora45/gnome-extensions.lock"
  }
}

fedora_manifest_path() {
  local manifest="$1"
  if [[ "${HOST_RELEASE:-44}" == 45 && "$manifest" == "$REPO_ROOT/manifests/packages-nautilus.txt" ]]; then
    fedora_require_profile 45 || return 60
    printf '%s\n' "$REPO_ROOT/profiles/fedora45/packages-nautilus.txt"
  else
    printf '%s\n' "$manifest"
  fi
}

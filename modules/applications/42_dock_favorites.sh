#!/usr/bin/env bash
set -Eeuo pipefail

dock_favorites_variant() {
  local favorites="${GNOME_DOCK_FAVORITES:-}" app variant='['
  local -a apps=()
  read -r -a apps <<< "$favorites"
  for app in "${apps[@]}"; do
    [[ "$variant" == '[' ]] || variant+=', '
    variant+="'$app'"
  done
  variant+=']'
  printf '%s\n' "$variant"
}

dock_launcher_exists() {
  local desktop_id="$1" root
  for root in \
    /usr/share/applications \
    /usr/local/share/applications \
    "$HOME/.local/share/applications" \
    "$HOME/.local/share/flatpak/exports/share/applications" \
    /var/lib/flatpak/exports/share/applications; do
    [[ -f "$root/$desktop_id" ]] && return 0
  done
  return 1
}

dock_favorites_precheck() {
  local app
  local -a apps=()
  is_true "${GNOME_DOCK_FAVORITES_ENABLED:-true}" || return 0
  command_exists gsettings || return "$EXIT_PRECHECK_FAILED"
  [[ -x "$REPO_ROOT/scripts/gnome/configure-dock-favorites.sh" ]] || return "$EXIT_PRECHECK_FAILED"
  gsettings list-keys org.gnome.shell 2>/dev/null | grep -Fxq favorite-apps || return "$EXIT_PRECHECK_FAILED"
  read -r -a apps <<< "${GNOME_DOCK_FAVORITES:-}"
  ((${#apps[@]} > 0)) || return "$EXIT_CONFIG_FAILED"
  for app in "${apps[@]}"; do
    [[ "$app" =~ ^[A-Za-z0-9._-]+\.desktop$ ]] || return "$EXIT_CONFIG_FAILED"
  done
  if printf '%s\n' "${apps[@]}" | sort | uniq -d | grep -q .; then
    log_error APPLICATIONS 'Duplicate desktop launcher in GNOME dock favorites'
    return "$EXIT_CONFIG_FAILED"
  fi
}

dock_favorites_plan() {
  printf 'GNOME curated dock: %s\n' "${GNOME_DOCK_FAVORITES:-disabled}"
}

dock_favorites_apply() {
  is_true "${GNOME_DOCK_FAVORITES_ENABLED:-true}" || return 0
  run_mutating APPLICATIONS "$REPO_ROOT/scripts/gnome/configure-dock-favorites.sh" "${GNOME_DOCK_FAVORITES:-}" || return "$EXIT_APPLY_FAILED"
}

dock_favorites_postcheck() {
  local expected actual app
  local -a apps=()
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${GNOME_DOCK_FAVORITES_ENABLED:-true}" || return 0
  expected="$(dock_favorites_variant)"
  actual="$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || true)"
  [[ "$actual" == "$expected" ]] || {
    log_error APPLICATIONS "GNOME dock favorites mismatch: expected $expected, got ${actual:-unavailable}"
    return "$EXIT_POSTCHECK_FAILED"
  }
  read -r -a apps <<< "${GNOME_DOCK_FAVORITES:-}"
  for app in "${apps[@]}"; do
    dock_launcher_exists "$app" || {
      log_error APPLICATIONS "Dock launcher is not exported: $app"
      return "$EXIT_POSTCHECK_FAILED"
    }
  done
}

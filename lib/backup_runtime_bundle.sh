#!/usr/bin/env bash

backup_runtime_bundle_init() {
  local runtime_root="${FEDORA_GNOME_CUSTOM_RUNTIME_ROOT:-}"
  EXIT_CONFIG_FAILED="${EXIT_CONFIG_FAILED:-60}"
  EXIT_PRECHECK_FAILED="${EXIT_PRECHECK_FAILED:-20}"

  if [[ -n "$runtime_root" ]]; then
    [[ -d "$runtime_root" \
      && -r "$runtime_root/runtime/backup-runtime.conf" \
      && -r "$runtime_root/runtime/APPLIED_SHA" \
      && -r "$runtime_root/lib/backup_runtime.sh" \
      && -r "$runtime_root/MANIFEST.sha256" ]] || {
      echo "Invalid installed backup runtime: $runtime_root" >&2
      return "$EXIT_PRECHECK_FAILED"
    }
    (
      cd "$runtime_root"
      sha256sum --check --status MANIFEST.sha256
    ) || {
      echo "Installed backup runtime integrity check failed: $runtime_root" >&2
      return "$EXIT_PRECHECK_FAILED"
    }
    # shellcheck disable=SC1090
    source "$runtime_root/runtime/backup-runtime.conf"
    # shellcheck disable=SC1090
    source "$runtime_root/lib/backup_runtime.sh"
    FEDORA_GNOME_CUSTOM_RUNTIME_SHA="$(<"$runtime_root/runtime/APPLIED_SHA")"
    [[ "$FEDORA_GNOME_CUSTOM_RUNTIME_SHA" =~ ^[0-9a-fA-F]{40}$ ]] || {
      echo 'Installed backup runtime has an invalid APPLIED_SHA.' >&2
      return "$EXIT_PRECHECK_FAILED"
    }
  else
    REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
    [[ -r "$REPO_ROOT/lib/bootstrap.sh" ]] || { echo 'Cannot locate repository backup runtime.' >&2; return "$EXIT_PRECHECK_FAILED"; }
    # shellcheck disable=SC1090
    source "$REPO_ROOT/lib/bootstrap.sh"
    engine_bootstrap
    # shellcheck disable=SC1090
    source "$REPO_ROOT/lib/backup_runtime.sh"
    FEDORA_GNOME_CUSTOM_RUNTIME_SHA="$(repo_commit)"
  fi

  STATE_ROOT="${FEDORA_GNOME_CUSTOM_STATE_ROOT:-${XDG_STATE_HOME:-$HOME/.local/state}/fedora-gnome-custom}"
  mkdir -p "$STATE_ROOT"
  export STATE_ROOT FEDORA_GNOME_CUSTOM_RUNTIME_SHA
}

backup_runtime_bundle_metadata() {
  printf 'runtime_sha=%s\n' "${FEDORA_GNOME_CUSTOM_RUNTIME_SHA:-unknown}"
}

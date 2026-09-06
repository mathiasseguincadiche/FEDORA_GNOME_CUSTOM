#!/usr/bin/env bash

application_runtime_contract_path() { printf '%s/manifests/application-runtime-contract.tsv\n' "$REPO_ROOT"; }
application_runtime_provenance_path() { printf '%s/manifests/application-provenance.tsv\n' "$REPO_ROOT"; }

application_runtime_unverified_allowed() {
  local id="$1"
  [[ " ${UNVERIFIED_FLATHUB_ALLOWLIST:-} " == *" $id "* ]]
}

application_runtime_provenance_matches() {
  local id="$1" delivery="$2" trust="$3" provenance
  [[ "$delivery" == fedora-rpm ]] && return 0
  provenance="$(application_runtime_provenance_path)"
  awk -F '\t' -v id="$id" -v delivery="$delivery" -v trust="$trust" \
    '$1==id && $2==delivery && $3==trust {found=1} END {exit !found}' "$provenance"
}

application_runtime_vendor_repo_exact() {
  local id="$1" source installed repo_dir
  repo_dir="${APPLICATION_RUNTIME_REPO_ROOT:-/etc/yum.repos.d}"
  case "$id" in
    code) source="$REPO_ROOT/config/repos/vscode.repo"; installed="$repo_dir/vscode.repo" ;;
    brave-browser) source="$REPO_ROOT/config/repos/brave-browser.repo"; installed="$repo_dir/brave-browser.repo" ;;
    *) return 1 ;;
  esac
  [[ -r "$source" && -r "$installed" ]] || return 1
  cmp -s "$source" "$installed"
}

application_runtime_validate_rpm() {
  local delivery="$1" package="$2" executable="$3" smoke_arg="$4"
  rpm -q "$package" >/dev/null 2>&1 || return 1
  command -v "$executable" >/dev/null 2>&1 || return 1
  timeout 20 "$executable" "$smoke_arg" >/dev/null 2>&1 || return 1
  if [[ "$delivery" == vendor-rpm ]]; then
    application_runtime_vendor_repo_exact "$package" || return 1
  fi
}

application_runtime_flatpak_desktop() {
  local id="$1" path
  for path in \
    "${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/exports/share/applications/$id.desktop" \
    "/var/lib/flatpak/exports/share/applications/$id.desktop"; do
    [[ -r "$path" ]] || continue
    printf '%s\n' "$path"
    return 0
  done
  return 1
}

application_runtime_validate_flatpak() {
  local id="$1" trust="$2" origin runtime desktop
  flatpak info "$id" >/dev/null 2>&1 || return 1
  origin="$(flatpak info --show-origin "$id" 2>/dev/null || true)"
  [[ "$origin" == flathub ]] || return 1
  runtime="$(flatpak info --show-runtime "$id" 2>/dev/null || true)"
  [[ -n "$runtime" ]] || return 1
  if [[ "$trust" == community-unverified ]]; then
    application_runtime_unverified_allowed "$id" || return 1
  fi
  timeout 30 flatpak run --command=/usr/bin/true "$id" >/dev/null 2>&1 || return 1
  desktop="$(application_runtime_flatpak_desktop "$id")" || return 1
  command -v desktop-file-validate >/dev/null 2>&1 || return 1
  desktop-file-validate "$desktop" >/dev/null 2>&1
}

application_runtime_validate_entry() {
  local delivery="$1" id="$2" executable="$3" smoke_arg="$4" trust="$5"
  application_runtime_provenance_matches "$id" "$delivery" "$trust" || return 1
  case "$delivery" in
    fedora-rpm|vendor-rpm)
      [[ "$executable" != - && "$smoke_arg" != - ]] || return 1
      application_runtime_validate_rpm "$delivery" "$id" "$executable" "$smoke_arg"
      ;;
    flatpak)
      application_runtime_validate_flatpak "$id" "$trust"
      ;;
    *) return 1 ;;
  esac
}

application_runtime_validate_contract() {
  local contract delivery id executable smoke_arg trust
  contract="$(application_runtime_contract_path)"
  [[ -r "$contract" && -r "$(application_runtime_provenance_path)" ]] || return 1
  while IFS=$'\t' read -r delivery id executable smoke_arg trust; do
    [[ -z "$delivery" || "$delivery" == \#* ]] && continue
    application_runtime_validate_entry "$delivery" "$id" "$executable" "$smoke_arg" "$trust" || return 1
  done < "$contract"
}

application_runtime_fingerprint_payload() {
  local delivery id executable smoke_arg trust value origin runtime
  while IFS=$'\t' read -r delivery id executable smoke_arg trust; do
    [[ -z "$delivery" || "$delivery" == \#* ]] && continue
    case "$delivery" in
      fedora-rpm|vendor-rpm)
        value="$(rpm -q --qf '%{NEVRA}' "$id" 2>/dev/null || printf missing)"
        printf '%s\t%s\t%s\n' "$delivery" "$id" "$value"
        ;;
      flatpak)
        value="$(flatpak info --show-commit "$id" 2>/dev/null || printf missing)"
        origin="$(flatpak info --show-origin "$id" 2>/dev/null || printf missing)"
        runtime="$(flatpak info --show-runtime "$id" 2>/dev/null || printf missing)"
        printf '%s\t%s\tcommit=%s\torigin=%s\truntime=%s\ttrust=%s\n' "$delivery" "$id" "$value" "$origin" "$runtime" "$trust"
        ;;
    esac
  done < "$(application_runtime_contract_path)"
}

application_runtime_fingerprint() { application_runtime_fingerprint_payload | sha256sum | awk '{print $1}'; }

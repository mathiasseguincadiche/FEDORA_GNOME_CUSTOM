#!/usr/bin/env bash
# REPO_ROOT is intentionally injected by the repository entrypoints before this library is sourced.
# shellcheck disable=SC2153

is_true() {
  case "${1,,}" in true|1|yes|on) return 0 ;; *) return 1 ;; esac
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

normalize_hex() {
  local value="${1,,}"
  printf '%s\n' "${value#0x}"
}

trim() {
  local value="$*"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

repo_commit() {
  git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || printf 'unknown\n'
}

runtime_virtualization_detect() {
  local virt=''
  if command_exists systemd-detect-virt; then
    virt="$(systemd-detect-virt --container 2>/dev/null || true)"
    if [[ -n "$virt" && "$virt" != none ]]; then
      printf 'container\n'
      return 0
    fi
    virt="$(systemd-detect-virt --vm 2>/dev/null || true)"
    if [[ -n "$virt" && "$virt" != none ]]; then
      printf 'vm\n'
      return 0
    fi
  fi
  if [[ -e /.dockerenv || -e /run/.containerenv ]]; then
    printf 'container\n'
    return 0
  fi
  return 1
}

runtime_environment_detect() {
  local virtualized=''
  if is_true "${GITHUB_ACTIONS:-false}" || is_true "${GITLAB_CI:-false}" || is_true "${CI:-false}"; then
    printf 'ci\n'
    return 0
  fi
  if grep -qiE '(microsoft|wsl)' /proc/sys/kernel/osrelease /proc/version 2>/dev/null; then
    printf 'wsl2\n'
    return 0
  fi
  virtualized="$(runtime_virtualization_detect || true)"
  if [[ -n "$virtualized" ]]; then
    printf '%s\n' "$virtualized"
    return 0
  fi
  printf 'baremetal\n'
}

runtime_environment() {
  printf '%s\n' "${RUNTIME_ENVIRONMENT:-$(runtime_environment_detect)}"
}

runtime_is_baremetal() { [[ "$(runtime_environment)" == baremetal ]]; }
runtime_is_wsl2() { [[ "$(runtime_environment)" == wsl2 ]]; }
runtime_is_ci() { [[ "$(runtime_environment)" == ci ]]; }
runtime_is_vm() { [[ "$(runtime_environment)" == vm ]]; }
runtime_is_container() { [[ "$(runtime_environment)" == container ]]; }

runtime_vm_vendor_detect() {
  command_exists systemd-detect-virt || return 1
  local vendor
  vendor="$(systemd-detect-virt --vm 2>/dev/null || true)"
  [[ -n "$vendor" && "$vendor" != none ]] || return 1
  printf '%s\n' "$vendor"
}

runtime_virtualbox_dmi_payload() {
  local path
  for path in /sys/class/dmi/id/product_name /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/board_vendor; do
    [[ -r "$path" ]] && cat "$path"
  done
}

runtime_is_virtualbox() {
  runtime_is_vm || return 1
  [[ "$(runtime_vm_vendor_detect || true)" == oracle ]] || return 1
  runtime_virtualbox_dmi_payload 2>/dev/null | grep -Eqi 'VirtualBox|Oracle|innotek'
}

#!/usr/bin/env bash
set -Eeuo pipefail

desktop_shell_ux_precheck() {
  is_true "${SHELL_UX_ENABLED:-true}" || return 0
  command_exists bash || return "$EXIT_PRECHECK_FAILED"
  [[ -n "${HOME:-}" && -d "$HOME" ]] || return "$EXIT_PRECHECK_FAILED"
}

desktop_shell_ux_plan() {
  cat <<'EOF_PLAN'
Provision the Fedora host Bash UX without replacing Bash or adding a prompt framework:
- bash-completion + fzf + zoxide + direnv from Fedora repositories
- managed modular profile under ~/.config/fedora-gnome-custom/bash
- long append-only synchronized history
- compact DevOps aliases with no destructive aliases
- local-only Git-aware two-line prompt
- one-time backup and idempotent managed block in ~/.bashrc
EOF_PLAN
}

desktop_shell_ux_apply() {
  is_true "${SHELL_UX_ENABLED:-true}" || return 0
  install_manifest_packages DESKTOP "$REPO_ROOT/manifests/packages-shell.txt" || return "$EXIT_APPLY_FAILED"
  run_mutating DESKTOP env \
    FGC_SHELL_SOURCE_DIR="$REPO_ROOT/shell/bash" \
    FGC_HISTSIZE="${SHELL_UX_HISTORY_SIZE:-50000}" \
    FGC_HISTFILESIZE="${SHELL_UX_HISTORY_FILE_SIZE:-100000}" \
    FGC_ENABLE_FZF="${SHELL_UX_ENABLE_FZF:-true}" \
    FGC_ENABLE_ZOXIDE="${SHELL_UX_ENABLE_ZOXIDE:-true}" \
    FGC_ENABLE_DIRENV="${SHELL_UX_ENABLE_DIRENV:-true}" \
    FGC_PROMPT_GIT="${SHELL_UX_PROMPT_GIT:-true}" \
    "$REPO_ROOT/scripts/shell/install-host-bash-ux.sh" || return "$EXIT_APPLY_FAILED"
}

desktop_shell_ux_postcheck() {
  is_true "${SHELL_UX_ENABLED:-true}" || return 0
  is_true "${DRY_RUN:-true}" && return 0
  "$REPO_ROOT/diagnostics/shell-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
}

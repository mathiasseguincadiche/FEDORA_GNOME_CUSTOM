# shellcheck shell=bash
# Fast native Bash prompt. Git inspection is local-only and never contacts a remote.
__fgc_prompt_update() {
  local rc=$?
  local path branch='' dirty='' git_segment='' rc_segment='' user host
  local reset='\[\e[0m\]' cyan='\[\e[1;36m\]' blue='\[\e[1;34m\]'
  local magenta='\[\e[1;35m\]' green='\[\e[1;32m\]' red='\[\e[1;31m\]'

  user="${USER:-$(id -un)}"
  host="${HOSTNAME:-$(hostname -s)}"

  history -a 2>/dev/null || true
  history -n 2>/dev/null || true

  if [[ "$PWD" == "$HOME" || "$PWD" == "$HOME/"* ]]; then
    path="~${PWD#"$HOME"}"
  else
    path="$PWD"
  fi
  if [[ "${FGC_PROMPT_GIT:-true}" == "true" ]] && command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || true)"
    if [[ -n "$branch" ]]; then
      if ! git diff --quiet --ignore-submodules -- 2>/dev/null || ! git diff --cached --quiet --ignore-submodules -- 2>/dev/null; then
        dirty='*'
      fi
      git_segment=" ${magenta}${branch}${dirty}${reset}"
    fi
  fi

  if (( rc != 0 )); then
    rc_segment=" ${red}✗ ${rc}${reset}"
  fi
  PS1="${cyan}${user}@${host%%.*}${reset} ${blue}${path}${reset}${git_segment}${rc_segment}\n${green}❯${reset} "
  return "$rc"
}

__fgc_install_prompt_command() {
  local item current declaration
  declaration="$(declare -p PROMPT_COMMAND 2>/dev/null || true)"
  if [[ "$declaration" == 'declare -a '* ]]; then
    for item in "${PROMPT_COMMAND[@]}"; do
      [[ "$item" == '__fgc_prompt_update' ]] && return 0
    done
    PROMPT_COMMAND=(__fgc_prompt_update "${PROMPT_COMMAND[@]}")
    return 0
  fi

  current="${PROMPT_COMMAND:-}"
  case ";$current;" in
    *';__fgc_prompt_update;'*) return 0 ;;
  esac
  unset PROMPT_COMMAND
  declare -ga PROMPT_COMMAND=(__fgc_prompt_update)
  [[ -n "$current" ]] && PROMPT_COMMAND+=("$current")
}

__fgc_install_prompt_command
unset -f __fgc_install_prompt_command

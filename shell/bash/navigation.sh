# Local-only navigation helpers. Nothing here performs network access.
if [[ "${FGC_ENABLE_ZOXIDE:-true}" == "true" ]] && command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi

if [[ "${FGC_ENABLE_DIRENV:-true}" == "true" ]] && command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"
fi

if [[ "${FGC_ENABLE_FZF:-true}" == "true" ]] && command -v fzf >/dev/null 2>&1; then
  export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:---height=40% --layout=reverse --border}"
  if [[ -r /usr/share/fzf/shell/key-bindings.bash ]]; then
    # shellcheck source=/dev/null
    source /usr/share/fzf/shell/key-bindings.bash
  elif fzf --bash >/dev/null 2>&1; then
    eval "$(fzf --bash)"
  fi
fi

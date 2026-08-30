# shellcheck shell=bash
# Fedora GNOME Custom — managed Bash entrypoint.
[[ $- == *i* ]] || return 0

FGC_BASH_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fedora-gnome-custom/bash"
for FGC_BASH_FILE in settings.sh history.sh aliases.sh navigation.sh completion.sh prompt.sh; do
  if [[ -r "$FGC_BASH_DIR/$FGC_BASH_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$FGC_BASH_DIR/$FGC_BASH_FILE"
  fi
done
unset FGC_BASH_FILE

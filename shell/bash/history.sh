# shellcheck shell=bash
# Long, append-only, multi-terminal Bash history.
HISTSIZE="${FGC_HISTSIZE:-50000}"
HISTFILESIZE="${FGC_HISTFILESIZE:-100000}"
HISTCONTROL="ignoreboth:erasedups"
HISTTIMEFORMAT='%F %T '
export HISTSIZE HISTFILESIZE HISTCONTROL HISTTIMEFORMAT
shopt -s histappend cmdhist

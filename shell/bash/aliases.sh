# shellcheck shell=bash
# Small, memorable aliases. No destructive command is hidden behind an alias.
alias ll='ls -lah --group-directories-first --color=auto'
alias la='ls -A --color=auto'
alias ..='cd ..'
alias ...='cd ../..'

alias g='git'
alias gs='git status --short --branch'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gpl='git pull --ff-only'
alias gl='git log --oneline --decorate --graph -20'

alias dc='docker compose'
alias dps='docker ps'

alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kd='kubectl describe'
alias kl='kubectl logs'

alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tff='terraform fmt'
alias tfv='terraform validate'

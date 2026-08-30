#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
version="$(<"$ROOT/VERSION")"
[[ "$(printf '%s\n' '0.9.2' "$version" | sort -V | head -n1)" == '0.9.2' ]]

for pkg in bash-completion fzf zoxide direnv; do
  grep -Fxq "$pkg" "$ROOT/manifests/packages-shell.txt"
done

grep -Fq 'desktop.shell_ux|DESKTOP|desktop.lifecycle|' "$ROOT/manifests/module-plan.conf"
grep -Fq 'applications.gtk4|APPLICATIONS|desktop.shell_ux|' "$ROOT/manifests/module-plan.conf"
grep -Fq 'install-host-bash-ux.sh' "$ROOT/modules/desktop/28_shell_ux.sh"
grep -Fq 'diagnostics/shell-doctor' "$ROOT/modules/desktop/28_shell_ux.sh"

grep -Fq '# >>> fedora-gnome-custom bash ux >>>' "$ROOT/scripts/shell/install-host-bash-ux.sh"
grep -Fq 'bashrc.pre-fgc' "$ROOT/scripts/shell/install-host-bash-ux.sh"
grep -Fq 'fedora-gnome-custom/bash/init.sh' "$ROOT/scripts/shell/install-host-bash-ux.sh"

grep -Fq 'HISTSIZE="${FGC_HISTSIZE:-50000}"' "$ROOT/shell/bash/history.sh"
grep -Fq 'histappend' "$ROOT/shell/bash/history.sh"
grep -Fq 'history -a' "$ROOT/shell/bash/prompt.sh"
grep -Fq 'history -n' "$ROOT/shell/bash/prompt.sh"
grep -Fq 'git symbolic-ref --quiet --short HEAD' "$ROOT/shell/bash/prompt.sh"
grep -Fq '❯' "$ROOT/shell/bash/prompt.sh"

for token in "alias gs=" "alias k=" "alias tf=" "alias dc="; do
  grep -Fq "$token" "$ROOT/shell/bash/aliases.sh"
done

for token in 'zoxide init bash' 'direnv hook bash' 'fzf --bash'; do
  grep -Fq "$token" "$ROOT/shell/bash/navigation.sh"
done

if grep -Eq '\b(starship|oh-my-bash|curl|wget|ssh|nc|kubectl|helm)\b' "$ROOT/shell/bash/prompt.sh"; then
  echo 'prompt must remain framework-free and local-only' >&2
  exit 1
fi
if grep -Eq "alias[[:space:]]+(rm|mv|cp|sudo)=" "$ROOT/shell/bash/aliases.sh"; then
  echo 'destructive/sudo aliases are forbidden' >&2
  exit 1
fi

grep -Fq 'packages-shell.txt' "$ROOT/.github/workflows/fedora-package-preflight.yml"
grep -Fq 'packages-shell.txt' "$ROOT/.github/workflows/fedora-host-pretest.yml"
grep -Fq 'test_shell_ux_contract.sh' "$ROOT/.github/workflows/tests.yml"
grep -Fq 'shell-doctor' "$ROOT/diagnostics/final-certification"
grep -Fq 'shell-doctor' "$ROOT/diagnostics/workstation-doctor"

echo 'Fedora host Bash UX contract: PASS'

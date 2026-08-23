#!/usr/bin/env bash
set -Eeuo pipefail

DEVOPS_USER="${DEVOPS_USER:-mathias}"
ok=0
ko=0

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf 'OK  %-18s %s\n' "$cmd" "$(command -v "$cmd")"
    ((ok+=1))
  else
    printf 'KO  %-18s missing\n' "$cmd"
    ((ko+=1))
  fi
}

for cmd in \
  git gh docker terraform ansible ansible-playbook az aws \
  kubectl helm kind python3 pip3 jq shellcheck \
  ssh rsync curl wget; do
  check_cmd "$cmd"
done

if systemctl is-active --quiet docker; then
  printf 'OK  %-18s active\n' docker.service
  ((ok+=1))
else
  printf 'KO  %-18s inactive\n' docker.service
  ((ko+=1))
fi

if systemctl is-active --quiet qemu-guest-agent; then
  printf 'OK  %-18s active\n' qemu-guest-agent
  ((ok+=1))
else
  printf 'KO  %-18s inactive\n' qemu-guest-agent
  ((ko+=1))
fi

if id -nG "$DEVOPS_USER" 2>/dev/null | tr ' ' '\n' | grep -Fxq docker; then
  printf 'OK  %-18s member\n' docker.group
  ((ok+=1))
else
  printf 'KO  %-18s %s not member\n' docker.group "$DEVOPS_USER"
  ((ko+=1))
fi

if [[ -r /var/lib/fedora-gnome-custom/ubuntu-devops-bootstrap.env ]]; then
  printf 'OK  %-18s present\n' bootstrap.marker
  ((ok+=1))
else
  printf 'KO  %-18s missing\n' bootstrap.marker
  ((ko+=1))
fi

printf '\nUbuntu DevOps verification: OK=%d KO=%d\n' "$ok" "$ko"
((ko == 0))

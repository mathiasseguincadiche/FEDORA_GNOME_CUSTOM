#!/usr/bin/env bash
set -Eeuo pipefail

DEVOPS_USER="${DEVOPS_USER:-mathias}"
ok=0
ko=0

pass() {
  printf 'OK  %-18s %s\n' "$1" "$2"
  ((ok+=1))
}

fail_check() {
  printf 'KO  %-18s %s\n' "$1" "$2"
  ((ko+=1))
}

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    pass "$cmd" "$(command -v "$cmd")"
  else
    fail_check "$cmd" missing
  fi
}

for cmd in \
  git gh glab docker terraform ansible ansible-playbook az aws \
  kubectl helm kind minikube k9s kubectx kubens yq \
  node npm corepack java javac mvn \
  python3 pip3 jq shellcheck ssh rsync curl wget; do
  check_cmd "$cmd"
done

if command -v node >/dev/null 2>&1; then
  node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true)"
  if [[ "$node_major" =~ ^[0-9]+$ ]] && (( node_major >= 22 )); then
    pass node.version "$(node --version)"
  else
    fail_check node.version "Node.js 22+ required; got $(node --version 2>/dev/null || echo unknown)"
  fi
fi

if command -v javac >/dev/null 2>&1; then
  javac_version="$(javac -version 2>&1 || true)"
  if grep -Eq '^javac 21([.]|$)' <<<"$javac_version"; then
    pass java.version "$javac_version"
  else
    fail_check java.version "OpenJDK 21 required; got $javac_version"
  fi
fi

if command -v yq >/dev/null 2>&1; then
  yq_version="$(yq --version 2>&1 || true)"
  if grep -Eqi 'mikefarah|version v?4[.]' <<<"$yq_version"; then
    pass yq.version "$yq_version"
  else
    fail_check yq.version "Go yq v4 required; got $yq_version"
  fi
fi

if command -v minikube >/dev/null 2>&1 && minikube version --short >/dev/null 2>&1; then
  pass minikube.version "$(minikube version --short)"
fi
if command -v k9s >/dev/null 2>&1 && k9s version --short >/dev/null 2>&1; then
  pass k9s.version "$(k9s version --short 2>&1 | head -n1)"
fi
if command -v glab >/dev/null 2>&1 && glab version >/dev/null 2>&1; then
  pass glab.version "$(glab version 2>&1 | head -n1)"
fi
if command -v corepack >/dev/null 2>&1 && corepack --version >/dev/null 2>&1; then
  pass corepack.version "$(corepack --version)"
fi
if command -v mvn >/dev/null 2>&1 && mvn -version >/dev/null 2>&1; then
  pass maven.version "$(mvn -version 2>&1 | head -n1)"
fi

if systemctl is-active --quiet docker; then
  pass docker.service active
else
  fail_check docker.service inactive
fi

if systemctl is-active --quiet qemu-guest-agent; then
  pass qemu-guest-agent active
else
  fail_check qemu-guest-agent inactive
fi

if id -nG "$DEVOPS_USER" 2>/dev/null | tr ' ' '\n' | grep -Fxq docker; then
  pass docker.group member
else
  fail_check docker.group "$DEVOPS_USER not member"
fi

user_home="$(getent passwd "$DEVOPS_USER" 2>/dev/null | cut -d: -f6)"
if [[ -n "$user_home" && -r "$user_home/.minikube/config/config.json" ]] && grep -q 'docker' "$user_home/.minikube/config/config.json"; then
  pass minikube.driver docker
else
  fail_check minikube.driver 'docker default not configured'
fi

if [[ -r /var/lib/fedora-gnome-custom/ubuntu-devops-bootstrap.env ]]; then
  pass bootstrap.marker present
else
  fail_check bootstrap.marker missing
fi

printf '\nUbuntu DevOps verification: OK=%d KO=%d\n' "$ok" "$ko"
((ko == 0))

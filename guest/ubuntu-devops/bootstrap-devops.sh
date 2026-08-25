#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
DEVOPS_USER="${DEVOPS_USER:-mathias}"

log() { printf '[ubuntu-devops] %s\n' "$*"; }
fail() { printf '[ubuntu-devops] ERROR: %s\n' "$*" >&2; exit 1; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || fail 'run this bootstrap as root'
[[ -r /etc/os-release ]] || fail '/etc/os-release missing'
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || fail "expected Ubuntu, got ${ID:-unknown}"
[[ "${VERSION_ID:-}" == 26.04* ]] || fail "expected Ubuntu 26.04, got ${VERSION_ID:-unknown}"

install -d -m 0755 /etc/apt/keyrings
apt-get update
apt-get install -y \
  apt-transport-https ca-certificates curl wget gnupg lsb-release \
  git git-lfs jq unzip zip rsync openssh-server qemu-guest-agent \
  python3 python3-pip python3-venv pipx \
  ansible ansible-core \
  build-essential make shellcheck \
  dnsutils traceroute iproute2 net-tools netcat-openbsd \
  htop tree tmux ripgrep less groff

log 'configure Docker official repository'
docker_suite="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
if ! curl -fsSL -o /dev/null "https://download.docker.com/linux/ubuntu/dists/${docker_suite}/Release"; then
  log "Docker repository has no ${docker_suite} suite yet; use noble compatibility suite"
  docker_suite="noble"
fi
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${docker_suite}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

log 'configure GitHub CLI official repository'
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
cat >/etc/apt/sources.list.d/github-cli.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main
EOF

log 'configure HashiCorp official repository'
hashicorp_suite="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
if ! curl -fsSL -o /dev/null "https://apt.releases.hashicorp.com/dists/${hashicorp_suite}/Release"; then
  log "HashiCorp repository has no ${hashicorp_suite} suite yet; use noble compatibility suite"
  hashicorp_suite="noble"
fi
curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/hashicorp-archive-keyring.gpg
cat >/etc/apt/sources.list.d/hashicorp.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com ${hashicorp_suite} main
EOF

log 'configure Azure CLI Microsoft repository'
azure_suite="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
if ! curl -fsSL -o /dev/null "https://packages.microsoft.com/repos/azure-cli/dists/${azure_suite}/Release"; then
  log "Azure CLI repository has no ${azure_suite} suite yet; use noble compatibility suite"
  azure_suite="noble"
fi
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor --yes -o /etc/apt/keyrings/microsoft.gpg
chmod go+r /etc/apt/keyrings/microsoft.gpg
cat >/etc/apt/sources.list.d/azure-cli.sources <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: ${azure_suite}
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/microsoft.gpg
EOF

log 'configure Kubernetes official repository'
kubernetes_release="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
kubernetes_minor="$(cut -d. -f1,2 <<<"$kubernetes_release")"
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${kubernetes_minor}/deb/Release.key" \
  | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 0644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${kubernetes_minor}/deb/ /
EOF

log 'configure current Helm Debian repository'
helm_expected_fpr="DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6"
helm_key="$(mktemp)"
trap 'rm -f "$helm_key"' EXIT
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey -o "$helm_key"
helm_actual_fpr="$(gpg --show-keys --with-colons "$helm_key" | awk -F: '$1 == "fpr" {print $10}' | head -n1)"
[[ "$helm_actual_fpr" == "$helm_expected_fpr" ]] || fail "unexpected Helm repository key fingerprint: $helm_actual_fpr"
gpg --dearmor --yes -o /etc/apt/keyrings/helm.gpg "$helm_key"
cat >/etc/apt/sources.list.d/helm-stable-debian.list <<'EOF'
deb [signed-by=/etc/apt/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main
EOF

apt-get update
apt-get install -y \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  gh terraform azure-cli kubectl helm

log 'install AWS CLI v2 from the AWS-owned installer'
aws_installer="$(mktemp)"
curl -fsSL https://awscli.amazonaws.com/v2/install.sh -o "$aws_installer"
chmod 0755 "$aws_installer"
if command -v aws >/dev/null 2>&1; then
  log "AWS CLI already installed; keep current v2 installation"
else
  "$aws_installer" --system
fi
rm -f "$aws_installer"

log 'install kind with release checksum verification'
kind_version="${KIND_VERSION:-}"
if [[ -z "$kind_version" ]]; then
  kind_version="$(curl -fsSL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | jq -r '.tag_name')"
fi
[[ "$kind_version" == v* ]] || fail "invalid kind version: $kind_version"
kind_tmp="$(mktemp -d)"
curl -fsSL "https://github.com/kubernetes-sigs/kind/releases/download/${kind_version}/kind-linux-amd64" -o "$kind_tmp/kind-linux-amd64"
curl -fsSL "https://github.com/kubernetes-sigs/kind/releases/download/${kind_version}/kind-linux-amd64.sha256sum" -o "$kind_tmp/kind-linux-amd64.sha256sum"
(
  cd "$kind_tmp"
  sha256sum -c kind-linux-amd64.sha256sum
)
install -m 0755 "$kind_tmp/kind-linux-amd64" /usr/local/bin/kind
rm -rf "$kind_tmp"

log 'enable guest services and operator access'
systemctl enable --now ssh
if [[ -e /dev/virtio-ports/org.qemu.guest_agent.0 ]]; then
  systemctl start qemu-guest-agent
else
  log 'qemu-guest-agent virtio channel is not exposed; leave the static service available for hypervisor activation'
fi
systemctl enable --now docker
getent passwd "$DEVOPS_USER" >/dev/null || fail "expected user $DEVOPS_USER is missing"
usermod -aG docker "$DEVOPS_USER"

log 'write completion marker'
install -d -m 0755 /var/lib/fedora-gnome-custom
{
  printf 'completed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'kubernetes_release=%s\n' "$kubernetes_release"
  printf 'kind_version=%s\n' "$kind_version"
} >/var/lib/fedora-gnome-custom/ubuntu-devops-bootstrap.env
chmod 0644 /var/lib/fedora-gnome-custom/ubuntu-devops-bootstrap.env

log 'bootstrap completed'

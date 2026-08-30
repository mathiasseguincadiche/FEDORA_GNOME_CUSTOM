#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
DEVOPS_USER="${DEVOPS_USER:-mathias}"
YQ_VERSION="${YQ_VERSION:-v4.53.3}"
YQ_LINUX_AMD64_SHA256="${YQ_LINUX_AMD64_SHA256:-fa52a4e758c63d38299163fbdd1edfb4c4963247918bf9c1c5d31d84789eded4}"
K9S_VERSION="${K9S_VERSION:-v0.51.0}"
K9S_LINUX_AMD64_SHA256="${K9S_LINUX_AMD64_SHA256:-c3752ad51a5a4015a113819c4eeb6e55a4d0e4b8e652494797532f6fc8161dd7}"

log() { printf '[ubuntu-devops] %s\n' "$*"; }
fail() { printf '[ubuntu-devops] ERROR: %s\n' "$*" >&2; exit 1; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || fail 'run this bootstrap as root'
[[ -r /etc/os-release ]] || fail '/etc/os-release missing'
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || fail "expected Ubuntu, got ${ID:-unknown}"
[[ "${VERSION_ID:-}" == 26.04* ]] || fail "expected Ubuntu 26.04, got ${VERSION_ID:-unknown}"
[[ "$(dpkg --print-architecture)" == amd64 ]] || fail 'this VM profile currently requires Ubuntu amd64'

install -d -m 0755 /etc/apt/keyrings
apt-get update
apt-get install -y software-properties-common
add-apt-repository -y universe
apt-get update
apt-get install -y \
  apt-transport-https ca-certificates curl wget gnupg lsb-release \
  git git-lfs jq unzip zip rsync openssh-server qemu-guest-agent \
  python3 python3-pip python3-venv pipx \
  ansible ansible-core \
  build-essential make shellcheck bash-completion \
  dnsutils traceroute iproute2 net-tools netcat-openbsd \
  htop tree tmux ripgrep less groff \
  glab nodejs npm node-corepack \
  openjdk-21-jdk maven \
  kubectx

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
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor --yes -o /etc/apt/keyrings/microsoft.gpg
chmod go+r /etc/apt/keyrings/microsoft.gpg

configure_azure_repository() {
  local suite="$1"
  cat >/etc/apt/sources.list.d/azure-cli.sources <<EOF
Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: ${suite}
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/microsoft.gpg
EOF
}

azure_suite="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
configure_azure_repository "$azure_suite"

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

# Microsoft can publish Release metadata for a new Ubuntu suite before the
# azure-cli package itself is available. Prefer the native suite, then fall
# back only to supported Ubuntu releases, and require APT to see the package.
if ! apt-cache show azure-cli >/dev/null 2>&1; then
  native_azure_suite="$azure_suite"
  azure_suite=""
  for candidate in noble jammy; do
    [[ "$candidate" == "$native_azure_suite" ]] && continue
    log "Azure CLI package unavailable for ${native_azure_suite}; test ${candidate} compatibility suite"
    configure_azure_repository "$candidate"
    apt-get update
    if apt-cache show azure-cli >/dev/null 2>&1; then
      azure_suite="$candidate"
      log "Azure CLI package resolved from ${azure_suite} compatibility suite"
      break
    fi
  done
  [[ -n "$azure_suite" ]] || fail "Azure CLI package unavailable for ${native_azure_suite}, noble and jammy"
else
  log "Azure CLI package resolved from native ${azure_suite} suite"
fi

apt-get install -y \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  gh terraform azure-cli kubectl helm

log 'install AWS CLI v2 from the AWS-owned installer'
aws_installer="$(mktemp)"
curl -fsSL https://awscli.amazonaws.com/v2/install.sh -o "$aws_installer"
chmod 0755 "$aws_installer"
if command -v aws >/dev/null 2>&1; then
  log 'AWS CLI already installed; keep current v2 installation'
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

log 'install Minikube from official release with checksum verification'
minikube_tmp="$(mktemp -d)"
curl -fsSL https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64 -o "$minikube_tmp/minikube-linux-amd64"
curl -fsSL https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64.sha256 -o "$minikube_tmp/minikube-linux-amd64.sha256"
minikube_sha="$(tr -d '[:space:]' <"$minikube_tmp/minikube-linux-amd64.sha256")"
[[ "$minikube_sha" =~ ^[0-9a-fA-F]{64}$ ]] || fail 'invalid Minikube checksum payload'
printf '%s  %s\n' "$minikube_sha" "$minikube_tmp/minikube-linux-amd64" | sha256sum -c -
install -m 0755 "$minikube_tmp/minikube-linux-amd64" /usr/local/bin/minikube
rm -rf "$minikube_tmp"

log "install yq ${YQ_VERSION} with pinned checksum"
yq_tmp="$(mktemp -d)"
curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -o "$yq_tmp/yq"
printf '%s  %s\n' "$YQ_LINUX_AMD64_SHA256" "$yq_tmp/yq" | sha256sum -c -
install -m 0755 "$yq_tmp/yq" /usr/local/bin/yq
rm -rf "$yq_tmp"

log "install K9s ${K9S_VERSION} with pinned checksum"
k9s_tmp="$(mktemp -d)"
k9s_archive="$k9s_tmp/k9s_Linux_amd64.tar.gz"
curl -fsSL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" -o "$k9s_archive"
printf '%s  %s\n' "$K9S_LINUX_AMD64_SHA256" "$k9s_archive" | sha256sum -c -
tar -xzf "$k9s_archive" -C "$k9s_tmp" k9s
install -m 0755 "$k9s_tmp/k9s" /usr/local/bin/k9s
rm -rf "$k9s_tmp"

log 'validate application toolchain majors'
node_major="$(node -p 'process.versions.node.split(".")[0]')"
[[ "$node_major" =~ ^[0-9]+$ ]] && (( node_major >= 22 )) || fail "Node.js 22+ required, got $(node --version)"
javac_major="$(javac -version 2>&1 | awk '{split($2,v,"."); print v[1]}')"
[[ "$javac_major" == 21 ]] || fail "OpenJDK 21 required, got $(javac -version 2>&1)"
corepack --version >/dev/null
npm --version >/dev/null
mvn -version >/dev/null

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

devops_home="$(getent passwd "$DEVOPS_USER" | cut -d: -f6)"
[[ -n "$devops_home" && -d "$devops_home" ]] || fail "home directory unavailable for $DEVOPS_USER"
runuser -u "$DEVOPS_USER" -- env HOME="$devops_home" minikube config set driver docker >/dev/null

log 'write completion marker'
install -d -m 0755 /var/lib/fedora-gnome-custom
{
  printf 'completed_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'kubernetes_release=%s\n' "$kubernetes_release"
  printf 'kind_version=%s\n' "$kind_version"
  printf 'minikube_version=%s\n' "$(minikube version --short)"
  printf 'node_version=%s\n' "$(node --version)"
  printf 'java_version=%s\n' "$(javac -version 2>&1)"
  printf 'yq_version=%s\n' "$YQ_VERSION"
  printf 'k9s_version=%s\n' "$K9S_VERSION"
  printf 'azure_suite=%s\n' "$azure_suite"
} >/var/lib/fedora-gnome-custom/ubuntu-devops-bootstrap.env
chmod 0644 /var/lib/fedora-gnome-custom/ubuntu-devops-bootstrap.env

log 'bootstrap completed: clone -> build/test -> containerize -> deploy toolchain is ready'

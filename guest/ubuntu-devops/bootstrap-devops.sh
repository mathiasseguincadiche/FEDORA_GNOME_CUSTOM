#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
DEVOPS_USER="${DEVOPS_USER:-mathias}"
KUBERNETES_MINOR="${KUBERNETES_MINOR:-v1.37}"
KIND_VERSION="${KIND_VERSION:-v0.33.0}"
MINIKUBE_VERSION="${MINIKUBE_VERSION:-v1.38.1}"
YQ_VERSION="${YQ_VERSION:-v4.53.3}"
YQ_LINUX_AMD64_SHA256="${YQ_LINUX_AMD64_SHA256:-fa52a4e758c63d38299163fbdd1edfb4c4963247918bf9c1c5d31d84789eded4}"
K9S_VERSION="${K9S_VERSION:-v0.51.0}"
K9S_LINUX_AMD64_SHA256="${K9S_LINUX_AMD64_SHA256:-c3752ad51a5a4015a113819c4eeb6e55a4d0e4b8e652494797532f6fc8161dd7}"
AWS_CLI_PGP_FINGERPRINT="${AWS_CLI_PGP_FINGERPRINT:-FB5DB77FD5C118B80511ADA8A6310ACC4672475C}"

log() { printf '[ubuntu-devops] %s\n' "$*"; }
fail() { printf '[ubuntu-devops] ERROR: %s\n' "$*" >&2; exit 1; }

write_aws_cli_public_key() {
  cat > "$1" <<'EOF'
-----BEGIN PGP PUBLIC KEY BLOCK-----

mQINBF2Cr7UBEADJZHcgusOJl7ENSyumXh85z0TRV0xJorM2B/JL0kHOyigQluUG
ZMLhENaG0bYatdrKP+3H91lvK050pXwnO/R7fB/FSTouki4ciIx5OuLlnJZIxSzx
PqGl0mkxImLNbGWoi6Lto0LYxqHN2iQtzlwTVmq9733zd3XfcXrZ3+LblHAgEt5G
TfNxEKJ8soPLyWmwDH6HWCnjZ/aIQRBTIQ05uVeEoYxSh6wOai7ss/KveoSNBbYz
gbdzoqI2Y8cgH2nbfgp3DSasaLZEdCSsIsK1u05CinE7k2qZ7KgKAUIcT/cR/grk
C6VwsnDU0OUCideXcQ8WeHutqvgZH1JgKDbznoIzeQHJD238GEu+eKhRHcz8/jeG
94zkcgJOz3KbZGYMiTh277Fvj9zzvZsbMBCedV1BTg3TqgvdX4bdkhf5cH+7NtWO
lrFj6UwAsGukBTAOxC0l/dnSmZhJ7Z1KmEWilro/gOrjtOxqRQutlIqG22TaqoPG
fYVN+en3Zwbt97kcgZDwqbuykNt64oZWc4XKCa3mprEGC3IbJTBFqglXmZ7l9ywG
EEUJYOlb2XrSuPWml39beWdKM8kzr1OjnlOm6+lpTRCBfo0wa9F8YZRhHPAkwKkX
XDeOGpWRj4ohOx0d2GWkyV5xyN14p2tQOCdOODmz80yUTgRpPVQUtOEhXQARAQAB
tCFBV1MgQ0xJIFRlYW0gPGF3cy1jbGlAYW1hem9uLmNvbT6JAlQEEwEIAD4CGwMF
CwkIBwIGFQoJCAsCBBYCAwECHgECF4AWIQT7Xbd/1cEYuAURraimMQrMRnJHXAUC
akV0ygUJDqP4lQAKCRCmMQrMRnJHXFHjD/9eyZLYcKuQOlLvtqSDtUBiEZf6ZZjM
i3ygYH8rJNtuToUH+HvSpe819urJCquXhDrlK6N+aqW0hCLtNABJG/vsafIgvIYJ
hSGgpgtNnQyMV1jViRWqPjbouw8OkYKBThUfT1i2Y+wn58ifs6ODBCmTexWtXspA
Si+Gt49xDOW0APmbOPnI+a4HJW6tVEo6MWS0WjzpiBayR3d1A4pt4YrPfSdDgpLo
h2SLQqlRqvvVZJaWBjhkErNFpfsBA06sDcPEOb0G8LBUbR4WOcdvhe5LubJbZuxC
AG9kNPCVeQP1ixwjgjXKysaxeQ6rv0VzIQgRp6tLVLWhy6AKDNvLjFSsmXZ1Wl08
Y/RlOHXlzLuQMRE6sR1wOdRxc9TsrNWTGiBK65cvSWOy03JeBkQQ8pesqltiyxI9
U21kkgiXtTSKNGfKK8pO27D81YANhRqPK7iTp6kuFiY2WtOg90KTMNlIT+Ff85Y2
b1rHj6Z0SrCkJujhWk3IBPic/wJgz01LEc/OAdUPlby90RJZcIBhSlWhT7mXnXIO
c0HWlNQrns2s3CTyYwZSiSlYe9ApeLwhjDo8NhbFuCAy61l6O5UsR4AfZxx/rGKv
2wFb1/RN/P4gNe6vmxZAPjR0AQcwD3tc2McimOLr/22kmPz8IH3I0X7WoSFr0Biz
E91G7bb0hOb/cA==
=knv7
-----END PGP PUBLIC KEY BLOCK-----
EOF
}

[[ ${EUID:-$(id -u)} -eq 0 ]] || fail 'run this bootstrap as root'
[[ -r /etc/os-release ]] || fail '/etc/os-release missing'
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == "ubuntu" ]] || fail "expected Ubuntu, got ${ID:-unknown}"
[[ "${VERSION_ID:-}" == 26.04* ]] || fail "expected Ubuntu 26.04, got ${VERSION_ID:-unknown}"
[[ "$(dpkg --print-architecture)" == amd64 ]] || fail 'this VM profile currently requires Ubuntu amd64'
[[ "$KUBERNETES_MINOR" =~ ^v[0-9]+[.][0-9]+$ ]] || fail "invalid Kubernetes minor: $KUBERNETES_MINOR"
[[ "$KIND_VERSION" =~ ^v[0-9]+[.][0-9]+[.][0-9]+$ ]] || fail "invalid kind version: $KIND_VERSION"
[[ "$MINIKUBE_VERSION" =~ ^v[0-9]+[.][0-9]+[.][0-9]+$ ]] || fail "invalid Minikube version: $MINIKUBE_VERSION"

install -d -m 0755 /etc/apt/keyrings
apt-get update
apt-get install -y software-properties-common
add-apt-repository -y universe
apt-get update
apt-get install -y \
  apt-transport-https ca-certificates curl wget gnupg lsb-release \
  git git-lfs jq unzip zip rsync openssh-server qemu-guest-agent \
  python3 python3-pip python3-venv python3-dev pipx \
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

log "configure Kubernetes ${KUBERNETES_MINOR} official repository"
kubernetes_minor="$KUBERNETES_MINOR"
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${kubernetes_minor}/deb/Release.key" \
  | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 0644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
cat >/etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${kubernetes_minor}/deb/ /
EOF

log 'configure current Helm Debian repository'
helm_expected_fpr="DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6"
helm_key="$(mktemp)"
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey -o "$helm_key"
helm_actual_fpr="$(gpg --show-keys --with-colons "$helm_key" | awk -F: '$1 == "fpr" {print $10; exit}')"
[[ "$helm_actual_fpr" == "$helm_expected_fpr" ]] || fail "unexpected Helm repository key fingerprint: $helm_actual_fpr"
gpg --dearmor --yes -o /etc/apt/keyrings/helm.gpg "$helm_key"
rm -f "$helm_key"
cat >/etc/apt/sources.list.d/helm-stable-debian.list <<'EOF'
deb [signed-by=/etc/apt/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main
EOF

apt-get update
if ! apt-cache show azure-cli >/dev/null 2>&1; then
  native_azure_suite="$azure_suite"
  azure_suite=""
  for candidate in noble jammy; do
    [[ "$candidate" == "$native_azure_suite" ]] && continue
    log "Azure CLI package unavailable for ${native_azure_suite}; test ${candidate} compatibility suite"
    configure_azure_repository "$candidate"
    apt-get update
    if apt-cache show azure-cli >/dev/null 2>&1; then azure_suite="$candidate"; log "Azure CLI package resolved from ${azure_suite} compatibility suite"; break; fi
  done
  [[ -n "$azure_suite" ]] || fail "Azure CLI package unavailable for ${native_azure_suite}, noble and jammy"
else
  log "Azure CLI package resolved from native ${azure_suite} suite"
fi

apt-get install -y \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  gh terraform azure-cli kubectl helm

kubernetes_release="$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion // empty')"
[[ "$kubernetes_release" == "${KUBERNETES_MINOR}."* ]] || fail "kubectl must stay on ${KUBERNETES_MINOR}.x, got ${kubernetes_release:-unknown}"

log 'install AWS CLI v2 from AWS-signed ZIP'
if command -v aws >/dev/null 2>&1 && aws --version 2>&1 | grep -q '^aws-cli/2[.]'; then
  log 'AWS CLI v2 already installed; keep current installation'
else
  aws_tmp="$(mktemp -d)"
  aws_zip="$aws_tmp/awscliv2.zip"
  aws_sig="$aws_tmp/awscliv2.zip.sig"
  aws_key="$aws_tmp/aws-cli-public-key.asc"
  aws_keyring="$aws_tmp/aws-cli-keyring.gpg"
  write_aws_cli_public_key "$aws_key"
  aws_actual_fpr="$(gpg --show-keys --with-colons "$aws_key" | awk -F: '$1 == "fpr" {print $10; exit}')"
  [[ "$aws_actual_fpr" == "$AWS_CLI_PGP_FINGERPRINT" ]] || fail "unexpected AWS CLI signing key fingerprint: $aws_actual_fpr"
  gpg --batch --yes --dearmor -o "$aws_keyring" "$aws_key"
  curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o "$aws_zip"
  curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip.sig -o "$aws_sig"
  gpgv --keyring "$aws_keyring" "$aws_sig" "$aws_zip" || fail 'AWS CLI signature verification failed'
  unzip -q "$aws_zip" -d "$aws_tmp"
  "$aws_tmp/aws/install" --install-dir /usr/local/aws-cli --bin-dir /usr/local/bin
  rm -rf "$aws_tmp"
fi
aws --version 2>&1 | grep -q '^aws-cli/2[.]' || fail 'AWS CLI v2 required'

log "install kind ${KIND_VERSION} with release checksum verification"
kind_version="$KIND_VERSION"
kind_tmp="$(mktemp -d)"
curl -fsSL "https://github.com/kubernetes-sigs/kind/releases/download/${kind_version}/kind-linux-amd64" -o "$kind_tmp/kind-linux-amd64"
curl -fsSL "https://github.com/kubernetes-sigs/kind/releases/download/${kind_version}/kind-linux-amd64.sha256sum" -o "$kind_tmp/kind-linux-amd64.sha256sum"
(
  cd "$kind_tmp"
  sha256sum -c kind-linux-amd64.sha256sum
)
install -m 0755 "$kind_tmp/kind-linux-amd64" /usr/local/bin/kind
rm -rf "$kind_tmp"
kind version | grep -Fq "$KIND_VERSION" || fail "kind version mismatch: $(kind version)"

log "install Minikube ${MINIKUBE_VERSION} with release checksum verification"
minikube_tmp="$(mktemp -d)"
curl -fsSL "https://github.com/kubernetes/minikube/releases/download/${MINIKUBE_VERSION}/minikube-linux-amd64" -o "$minikube_tmp/minikube-linux-amd64"
curl -fsSL "https://github.com/kubernetes/minikube/releases/download/${MINIKUBE_VERSION}/minikube-linux-amd64.sha256" -o "$minikube_tmp/minikube-linux-amd64.sha256"
minikube_sha="$(tr -d '[:space:]' <"$minikube_tmp/minikube-linux-amd64.sha256")"
[[ "$minikube_sha" =~ ^[0-9a-fA-F]{64}$ ]] || fail 'invalid Minikube checksum payload'
printf '%s  %s\n' "$minikube_sha" "$minikube_tmp/minikube-linux-amd64" | sha256sum -c -
install -m 0755 "$minikube_tmp/minikube-linux-amd64" /usr/local/bin/minikube
rm -rf "$minikube_tmp"
[[ "$(minikube version --short)" == "$MINIKUBE_VERSION" ]] || fail "Minikube version mismatch: $(minikube version --short)"

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
if [[ "$node_major" =~ ^[0-9]+$ ]] && (( node_major >= 22 )); then log "Node.js accepted: $(node --version)"; else fail "Node.js 22+ required, got $(node --version)"; fi
javac_major="$(javac -version 2>&1 | awk '{split($2,v,"."); print v[1]}')"
[[ "$javac_major" == 21 ]] || fail "OpenJDK 21 required, got $(javac -version 2>&1)"
corepack --version >/dev/null
npm --version >/dev/null
mvn -version >/dev/null

log 'enable guest services and operator access'
systemctl enable --now ssh
if [[ -e /dev/virtio-ports/org.qemu.guest_agent.0 ]]; then systemctl start qemu-guest-agent; else log 'qemu-guest-agent virtio channel is not exposed; leave the static service available for hypervisor activation'; fi
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
  printf 'kubernetes_minor=%s\n' "$KUBERNETES_MINOR"
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

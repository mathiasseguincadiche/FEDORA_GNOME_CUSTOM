#!/usr/bin/env bash
set -Eeuo pipefail
# sudo on Enterprise Linux can omit /usr/local/bin from secure_path.
# Use only root-owned system directories for the reviewed upstream binaries.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

DEVOPS_USER="${DEVOPS_USER:-mathias}"
KUBERNETES_MINOR="${KUBERNETES_MINOR:-v1.37}"
KIND_VERSION="${KIND_VERSION:-v0.33.0}"
MINIKUBE_VERSION="${MINIKUBE_VERSION:-v1.38.1}"
YQ_VERSION="${YQ_VERSION:-v4.53.3}"
YQ_LINUX_AMD64_SHA256="${YQ_LINUX_AMD64_SHA256:-fa52a4e758c63d38299163fbdd1edfb4c4963247918bf9c1c5d31d84789eded4}"
K9S_VERSION="${K9S_VERSION:-v0.51.0}"
K9S_LINUX_AMD64_SHA256="${K9S_LINUX_AMD64_SHA256:-c3752ad51a5a4015a113819c4eeb6e55a4d0e4b8e652494797532f6fc8161dd7}"
AWS_CLI_PGP_FINGERPRINT="${AWS_CLI_PGP_FINGERPRINT:-FB5DB77FD5C118B80511ADA8A6310ACC4672475C}"

log() { printf '[rocky-devops] %s\n' "$*"; }
fail() { printf '[rocky-devops] ERROR: %s\n' "$*" >&2; exit 1; }

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
[[ "${ID:-}" == "rocky" ]] || fail "expected Rocky Linux, got ${ID:-unknown}"
[[ "${VERSION_ID:-}" == 10.2 ]] || fail "expected Rocky Linux 10.2, got ${VERSION_ID:-unknown}"
[[ "$(uname -m)" == x86_64 ]] || fail 'this VM profile currently requires Rocky Linux x86_64'
[[ "$KUBERNETES_MINOR" =~ ^v[0-9]+[.][0-9]+$ ]] || fail "invalid Kubernetes minor: $KUBERNETES_MINOR"
[[ "$KIND_VERSION" =~ ^v[0-9]+[.][0-9]+[.][0-9]+$ ]] || fail "invalid kind version: $KIND_VERSION"
[[ "$MINIKUBE_VERSION" =~ ^v[0-9]+[.][0-9]+[.][0-9]+$ ]] || fail "invalid Minikube version: $MINIKUBE_VERSION"

# A rerun cannot leave an old success marker after a failed transaction.
rm -f /var/lib/fedora-gnome-custom/rocky-devops-bootstrap.env
[[ "$DEVOPS_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || fail 'invalid DevOps user'
getent passwd "$DEVOPS_USER" >/dev/null || fail "expected user $DEVOPS_USER is missing"
[[ "$(getenforce)" == Enforcing ]] || fail 'SELinux must remain enforcing'
log 'configure Rocky 10 CRB and EPEL 10'
dnf -y install dnf-plugins-core ca-certificates curl wget gnupg2
dnf config-manager --set-enabled crb
# Official Fedora EPEL release package installs its RPM trust/repository policy.
dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-10.noarch.rpm
dnf -y upgrade --refresh
dnf -y install \
  git git-lfs jq unzip zip rsync openssh-server qemu-guest-agent \
  python3 python3-pip python3-devel pipx ansible-core \
  gcc gcc-c++ make shellcheck bash-completion \
  bind-utils traceroute iproute net-tools nmap-ncat \
  htop tree tmux ripgrep less groff glab \
  nodejs npm java-21-openjdk-devel maven \
  container-selinux policycoreutils

log 'configure native Enterprise Linux 10 RPM repositories'
cat >/etc/yum.repos.d/devops-docker.repo <<'EOF'
[devops-docker]
name=Docker official RHEL 10
baseurl=https://download.docker.com/linux/rhel/10/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/rhel/gpg
EOF
cat >/etc/yum.repos.d/devops-gh.repo <<'EOF'
[devops-gh]
name=GitHub CLI official RPM
baseurl=https://cli.github.com/packages/rpm
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://cli.github.com/packages/githubcli-archive-keyring.gpg
EOF
cat >/etc/yum.repos.d/devops-hashicorp.repo <<'EOF'
[devops-hashicorp]
name=HashiCorp official RHEL 10
baseurl=https://rpm.releases.hashicorp.com/RHEL/10/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://rpm.releases.hashicorp.com/gpg
EOF
cat >/etc/yum.repos.d/devops-azure.repo <<'EOF'
[devops-azure]
name=Microsoft official RHEL 10
baseurl=https://packages.microsoft.com/rhel/10/prod
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft-2025.asc
EOF
cat >/etc/yum.repos.d/devops-kubernetes.repo <<EOF
[devops-kubernetes]
name=Kubernetes ${KUBERNETES_MINOR}
baseurl=https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR}/rpm/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR}/rpm/repodata/repomd.xml.key
EOF
# No EL9/EL8 compatibility fallback, --nogpgcheck or --skip-broken.
dnf -y install \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  gh terraform azure-cli kubectl

# EPEL 10.2 has no kubectx RPM; preserve kubectx/kubens with reviewed
# upstream v0.11.0 assets. Digests come from ahmetb/kubectx release metadata.
kubectx_tmp="$(mktemp -d)"
for tool in kubectx kubens; do
  case "$tool" in
    kubectx) expected_sha=08e031c54fbffb3f100e904e4eae94bba2730fedf4869921fda79e4d7a8f5d4c ;;
    kubens) expected_sha=326c021c7b35468ed9a187b361198d0f22ae32828139c65eb6670c0d8301cc09 ;;
  esac
  archive="$tool"_v0.11.0_linux_x86_64.tar.gz
  curl -fsSL "https://github.com/ahmetb/kubectx/releases/download/v0.11.0/$archive" -o "$kubectx_tmp/$archive"
  printf '%s  %s\n' "$expected_sha" "$kubectx_tmp/$archive" | sha256sum -c -
  tar -xzf "$kubectx_tmp/$archive" -C "$kubectx_tmp" "$tool"
  install -m 0755 "$kubectx_tmp/$tool" "/usr/local/bin/$tool"
done
rm -rf "$kubectx_tmp"

log 'install Corepack at an explicit npm version (registry integrity checked by npm)'
npm install --global corepack@0.34.5
log 'install Helm from an explicit upstream release and its published SHA-256'
helm_version=v4.3.0
helm_tmp="$(mktemp -d)"
helm_archive="helm-$helm_version-linux-amd64.tar.gz"
curl -fsSL "https://get.helm.sh/$helm_archive" -o "$helm_tmp/$helm_archive"
curl -fsSL "https://get.helm.sh/$helm_archive.sha256sum" -o "$helm_tmp/$helm_archive.sha256sum"
(cd "$helm_tmp"; sha256sum -c "$helm_archive.sha256sum")
tar -xzf "$helm_tmp/$helm_archive" -C "$helm_tmp" linux-amd64/helm
install -m 0755 "$helm_tmp/linux-amd64/helm" /usr/local/bin/helm
rm -rf "$helm_tmp"
helm version --short | grep -Fq "$helm_version"

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
systemctl enable --now sshd
if [[ -e /dev/virtio-ports/org.qemu.guest_agent.0 ]]; then systemctl start qemu-guest-agent; else log 'qemu-guest-agent virtio channel is not exposed; leave the static service available for hypervisor activation'; fi
systemctl enable --now docker
getent passwd "$DEVOPS_USER" >/dev/null || fail "expected user $DEVOPS_USER is missing"
usermod -aG docker "$DEVOPS_USER"
devops_home="$(getent passwd "$DEVOPS_USER" | cut -d: -f6)"
[[ -n "$devops_home" && -d "$devops_home" ]] || fail "home directory unavailable for $DEVOPS_USER"
runuser -u "$DEVOPS_USER" -- env HOME="$devops_home" PATH="$PATH" minikube config set driver docker >/dev/null

log 'verify SSH and SELinux policy'
sshd -T | grep -Fxq 'passwordauthentication no' || fail 'SSH password authentication must remain disabled'
[[ "$(getenforce)" == Enforcing ]] || fail 'SELinux enforcement lost'
log 'write completion marker'
install -d -m 0755 /var/lib/fedora-gnome-custom
rpm -qa --qf '%{NAME} %{VERSION}-%{RELEASE} %{ARCH}\n' | sort >/var/lib/fedora-gnome-custom/rocky-devops-packages.txt
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
  printf 'rpm_release=%s\n' "$VERSION_ID"
  printf 'helm_version=%s\n' "$helm_version"
} >/var/lib/fedora-gnome-custom/rocky-devops-bootstrap.env
chmod 0644 /var/lib/fedora-gnome-custom/rocky-devops-bootstrap.env
log 'bootstrap completed: clone -> build/test -> containerize -> deploy toolchain is ready'

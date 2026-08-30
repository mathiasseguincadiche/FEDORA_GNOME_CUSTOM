#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOOT="$ROOT/guest/ubuntu-devops/bootstrap-devops.sh"
VERIFY="$ROOT/guest/ubuntu-devops/verify-devops.sh"
CREATE="$ROOT/scripts/kvm/create_ubuntu_devops_vm.sh"
VM_PRETEST="$ROOT/.github/scripts/vm-pretest.sh"

for token in \
  docker-ce docker-compose-plugin gh glab terraform azure-cli kubectl helm \
  ansible aws kind minikube qemu-guest-agent openssh-server \
  nodejs npm node-corepack openjdk-21-jdk maven kubectx \
  yq k9s \
  packages.buildkite.com/helm-linux/helm-debian \
  pkgs.k8s.io apt.releases.hashicorp.com cli.github.com/packages \
  download.docker.com packages.microsoft.com; do
  grep -Fq "$token" "$BOOT" || { echo "missing Ubuntu DevOps bootstrap contract: $token" >&2; exit 1; }
done

for token in glab minikube k9s kubectx kubens yq node npm corepack java javac mvn; do
  grep -Fq "$token" "$VERIFY" || { echo "missing Ubuntu ready-to-work verification: $token" >&2; exit 1; }
done

grep -Fq 'YQ_VERSION="${YQ_VERSION:-v4.53.3}"' "$BOOT"
grep -Fq 'fa52a4e758c63d38299163fbdd1edfb4c4963247918bf9c1c5d31d84789eded4' "$BOOT"
grep -Fq 'K9S_VERSION="${K9S_VERSION:-v0.51.0}"' "$BOOT"
grep -Fq 'c3752ad51a5a4015a113819c4eeb6e55a4d0e4b8e652494797532f6fc8161dd7' "$BOOT"
grep -Fq 'minikube-linux-amd64.sha256' "$BOOT"
grep -Fq 'sha256sum -c' "$BOOT"
grep -Fq 'helm_expected_fpr=' "$BOOT"
grep -Fq 'configure_azure_repository' "$BOOT"
grep -Fq 'apt-cache show azure-cli' "$BOOT"
grep -Fq 'for candidate in noble jammy' "$BOOT"
grep -Fq 'azure_suite=%s' "$BOOT"
grep -Fq 'minikube config set driver docker' "$BOOT"
grep -Fq 'Node.js 22+ required' "$BOOT"
grep -Fq 'OpenJDK 21 required' "$BOOT"

grep -Fq 'runtime-prompt' "$ROOT/config/vm-profiles.conf"
grep -Fq 'openssl passwd -6' "$CREATE"
grep -Fq 'encoding: b64' "$CREATE"
grep -Fq '/usr/local/sbin/devops-bootstrap.sh' "$CREATE"
grep -Fq 'cloud-localds' "$CREATE"
grep -Fq 'SSH/SFTP' "$CREATE"

grep -Fq 'application toolchain smoke' "$VM_PRETEST"
grep -Fq 'javac Hello.java' "$VM_PRETEST"
grep -Fq 'minikube config get driver' "$VM_PRETEST"
grep -Fq 'REAL UBUNTU 26.04 READY-TO-WORK DEVOPS VM PRE-TEST PASS' "$VM_PRETEST"

if grep -RInEi --exclude='test_ubuntu_devops_bootstrap_contract.sh' 'virtiofs|virtiofsd|hostshare|/mnt/hostshare|/data/libvirt/shared' "$ROOT/guest/ubuntu-devops" "$ROOT/scripts/kvm/create_ubuntu_devops_vm.sh" >/dev/null; then
  echo 'obsolete VirtioFS/host-directory sharing found in Ubuntu provisioning' >&2
  exit 1
fi
if grep -RInE --exclude='test_ubuntu_devops_bootstrap_contract.sh' '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh)' "$ROOT/guest/ubuntu-devops" "$ROOT/scripts/kvm" >/dev/null; then
  echo 'forbidden curl/wget pipe-to-shell pattern found in Ubuntu/KVM provisioning' >&2
  exit 1
fi
if grep -RInE --exclude='test_ubuntu_devops_bootstrap_contract.sh' 'guest_password=.*guest|password:[[:space:]]*guest|passwd:[[:space:]]*guest' "$ROOT/guest/ubuntu-devops" "$ROOT/scripts/kvm" >/dev/null; then
  echo 'forbidden clear-text guest password pattern found' >&2
  exit 1
fi

echo 'ubuntu devops ready-to-work bootstrap contract: PASS'

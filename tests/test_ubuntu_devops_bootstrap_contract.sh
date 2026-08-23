#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BOOT="$ROOT/guest/ubuntu-devops/bootstrap-devops.sh"
CREATE="$ROOT/scripts/kvm/create_ubuntu_devops_vm.sh"

for token in \
  docker-ce docker-compose-plugin gh terraform azure-cli kubectl helm \
  ansible aws kind qemu-guest-agent openssh-server \
  packages.buildkite.com/helm-linux/helm-debian \
  pkgs.k8s.io apt.releases.hashicorp.com cli.github.com/packages \
  download.docker.com packages.microsoft.com; do
  grep -Fq "$token" "$BOOT" || { echo "missing Ubuntu DevOps bootstrap contract: $token" >&2; exit 1; }
done

grep -Fq 'sha256sum -c' "$BOOT"
grep -Fq 'helm_expected_fpr=' "$BOOT"
grep -Fq 'runtime-prompt' "$ROOT/config/vm-profiles.conf"
grep -Fq 'openssl passwd -6' "$CREATE"
grep -Fq 'encoding: b64' "$CREATE"
grep -Fq '/usr/local/sbin/devops-bootstrap.sh' "$CREATE"
grep -Fq 'driver.type=virtiofs' "$CREATE"
grep -Fq 'memorybacking source.type=memfd,access.mode=shared' "$CREATE"
grep -Fq 'cloud-localds' "$CREATE"

! grep -RInE --exclude='test_ubuntu_devops_bootstrap_contract.sh' '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(bash|sh)' "$ROOT/guest/ubuntu-devops" "$ROOT/scripts/kvm" >/dev/null
! grep -RInE --exclude='test_ubuntu_devops_bootstrap_contract.sh' 'guest_password=.*guest|password:[[:space:]]*guest|passwd:[[:space:]]*guest' "$ROOT/guest/ubuntu-devops" "$ROOT/scripts/kvm" >/dev/null

echo 'ubuntu devops bootstrap contract: PASS'

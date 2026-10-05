#!/usr/bin/env bash
set -Eeuo pipefail
# sudo on Enterprise Linux can omit /usr/local/bin from secure_path.
# Use only root-owned system directories for the reviewed upstream binaries.
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

DEVOPS_USER="${DEVOPS_USER:-mathias}"
EXPECTED_KUBERNETES_MINOR="${EXPECTED_KUBERNETES_MINOR:-v1.37}"
EXPECTED_KIND_VERSION="${EXPECTED_KIND_VERSION:-v0.33.0}"
EXPECTED_MINIKUBE_VERSION="${EXPECTED_MINIKUBE_VERSION:-v1.38.1}"
# Identity and enforcement are part of qualification, not inferred from filenames.
[[ -r /etc/os-release ]] || exit 1
# shellcheck disable=SC1091
source /etc/os-release
[[ "$ID" == rocky && "$VERSION_ID" == 10.2 && "$(uname -m)" == x86_64 ]] || { echo 'Rocky Linux 10.2 x86_64 required' >&2; exit 1; }
[[ "$(getenforce)" == Enforcing ]] || { echo 'SELinux enforcing required' >&2; exit 1; }
ok=0
ko=0

pass() { printf 'OK  %-18s %s\n' "$1" "$2"; ((ok+=1)); }
fail_check() { printf 'KO  %-18s %s\n' "$1" "$2"; ((ko+=1)); }
check_cmd() { local cmd="$1"; if command -v "$cmd" >/dev/null 2>&1; then pass "$cmd" "$(command -v "$cmd")"; else fail_check "$cmd" missing; fi; }

for cmd in git gh glab docker terraform ansible ansible-playbook az aws kubectl helm kind minikube k9s kubectx kubens yq node npm corepack java javac mvn python3 pip3 pipx jq shellcheck ssh rsync curl wget; do check_cmd "$cmd"; done

if command -v python3 >/dev/null 2>&1; then
  python_version="$(python3 --version 2>&1 || true)"
  if grep -Eq '^Python 3[.]' <<<"$python_version"; then pass python.version "$python_version"; else fail_check python.version "Python 3 required; got $python_version"; fi
fi
if command -v pip3 >/dev/null 2>&1; then
  pip_version="$(python3 -m pip --version 2>&1 || true)"
  if [[ "$pip_version" == pip\ * ]]; then pass pip.version "$pip_version"; else fail_check pip.version "python3 -m pip failed: $pip_version"; fi
fi
if command -v pipx >/dev/null 2>&1; then
  pipx_version="$(pipx --version 2>&1 || true)"
  if [[ -n "$pipx_version" ]]; then pass pipx.version "$pipx_version"; else fail_check pipx.version unavailable; fi
fi
venv_root="$(mktemp -d)"
if python3 -m venv "$venv_root/venv" >/dev/null 2>&1 && "$venv_root/venv/bin/python" -c 'import sys; assert sys.version_info.major == 3' >/dev/null 2>&1; then
  pass python.venv 'python3 -m venv functional'
else
  fail_check python.venv 'python3 -m venv failed'
fi
rm -rf "$venv_root"

if command -v node >/dev/null 2>&1; then node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || true)"; if [[ "$node_major" =~ ^[0-9]+$ ]] && (( node_major >= 22 )); then pass node.version "$(node --version)"; else fail_check node.version "Node.js 22+ required; got $(node --version 2>/dev/null || echo unknown)"; fi; fi
if command -v javac >/dev/null 2>&1; then javac_version="$(javac -version 2>&1 || true)"; if grep -Eq '^javac 21([.]|$)' <<<"$javac_version"; then pass java.version "$javac_version"; else fail_check java.version "OpenJDK 21 required; got $javac_version"; fi; fi
if command -v yq >/dev/null 2>&1; then yq_version="$(yq --version 2>&1 || true)"; if grep -Eqi 'mikefarah|version v?4[.]' <<<"$yq_version"; then pass yq.version "$yq_version"; else fail_check yq.version "Go yq v4 required; got $yq_version"; fi; fi

if command -v kubectl >/dev/null 2>&1; then kubernetes_version="$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion // empty')"; if [[ "$kubernetes_version" == "${EXPECTED_KUBERNETES_MINOR}."* ]]; then pass kubectl.version "$kubernetes_version"; else fail_check kubectl.version "expected ${EXPECTED_KUBERNETES_MINOR}.x; got ${kubernetes_version:-unknown}"; fi; fi
if command -v kind >/dev/null 2>&1; then kind_version="$(kind version 2>&1 || true)"; if grep -Fq "$EXPECTED_KIND_VERSION" <<<"$kind_version"; then pass kind.version "$kind_version"; else fail_check kind.version "expected $EXPECTED_KIND_VERSION; got $kind_version"; fi; fi
if command -v minikube >/dev/null 2>&1; then minikube_version="$(minikube version --short 2>/dev/null || true)"; if [[ "$minikube_version" == "$EXPECTED_MINIKUBE_VERSION" ]]; then pass minikube.version "$minikube_version"; else fail_check minikube.version "expected $EXPECTED_MINIKUBE_VERSION; got ${minikube_version:-unknown}"; fi; fi
if command -v aws >/dev/null 2>&1; then aws_version="$(aws --version 2>&1 || true)"; if grep -q '^aws-cli/2[.]' <<<"$aws_version"; then pass aws.version "$aws_version"; else fail_check aws.version "AWS CLI v2 required; got $aws_version"; fi; fi
# A present executable that fails at runtime is a KO, never a silent skip.
check_runtime() {
  local label="$1" output
  shift
  if output="$("$@" 2>&1)"; then
    pass "$label" "${output%%$'\n'*}"
  else
    fail_check "$label" "$* failed"
  fi
}
check_runtime k9s.version k9s version --short
check_runtime glab.version glab version
check_runtime corepack.version corepack --version
check_runtime maven.version mvn -version
check_runtime terraform.version terraform version
check_runtime ansible.version ansible --version
check_runtime azure.version az --version
check_runtime gh.version gh version
check_runtime helm.version helm version --short
check_runtime docker.api docker info --format '{{.ServerVersion}}'

if systemctl is-active --quiet sshd; then pass sshd.service active; else fail_check sshd.service inactive; fi
if systemctl is-active --quiet docker; then pass docker.service active; else fail_check docker.service inactive; fi
if systemctl is-active --quiet qemu-guest-agent; then pass qemu-guest-agent active; else fail_check qemu-guest-agent inactive; fi
if id -nG "$DEVOPS_USER" 2>/dev/null | tr ' ' '\n' | grep -Fxq docker; then pass docker.group member; else fail_check docker.group "$DEVOPS_USER not member"; fi

sshd_effective="$(sshd -T 2>/dev/null || true)"
if grep -Fxq 'passwordauthentication no' <<<"$sshd_effective"; then pass ssh.password-auth disabled; else fail_check ssh.password-auth 'PasswordAuthentication must be disabled'; fi

user_home="$(getent passwd "$DEVOPS_USER" 2>/dev/null | cut -d: -f6)"
if [[ -n "$user_home" && -r "$user_home/.minikube/config/config.json" ]] && grep -q 'docker' "$user_home/.minikube/config/config.json"; then pass minikube.driver docker; else fail_check minikube.driver 'docker default not configured'; fi
if [[ -s /var/lib/fedora-gnome-custom/rocky-devops-bootstrap.env && -s /var/lib/fedora-gnome-custom/rocky-devops-packages.txt ]]; then pass bootstrap.marker present; else fail_check bootstrap.marker missing; fi
printf '\nRocky DevOps verification: OK=%d KO=%d\n' "$ok" "$ko"
((ko == 0))

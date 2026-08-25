#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for file in .github/workflows/non-regression.yml .github/workflows/fedora-host-pretest.yml .github/workflows/vm-pretest.yml .github/scripts/vm-pretest.sh; do
  [[ -f "$ROOT/$file" ]] || { echo "missing CI maturity file: $file" >&2; exit 1; }
done
grep -Fq 'fedora:44' "$ROOT/.github/workflows/fedora-host-pretest.yml"
grep -Fq 'Install Fedora-native base contract' "$ROOT/.github/workflows/fedora-host-pretest.yml"
grep -Fq 'Validate multimedia provider convergence' "$ROOT/.github/workflows/fedora-host-pretest.yml"
grep -Fq 'ubuntu-26.04-server-cloudimg-amd64.img' "$ROOT/.github/scripts/vm-pretest.sh"
grep -Fq 'gpgv --keyring /usr/share/keyrings/ubuntu-cloudimage-keyring.gpg' "$ROOT/.github/scripts/vm-pretest.sh"
grep -Fq 'guest/ubuntu-devops/bootstrap-devops.sh' "$ROOT/.github/scripts/vm-pretest.sh"
grep -Fq 'docker run --rm hello-world' "$ROOT/.github/scripts/vm-pretest.sh"
grep -Fq 'sudo reboot' "$ROOT/.github/scripts/vm-pretest.sh"
grep -Fq 'actions/upload-artifact@v4' "$ROOT/.github/workflows/vm-pretest.yml"
grep -Fq 'Backup fail-closed invariants' "$ROOT/.github/workflows/non-regression.yml"
echo 'CI maturity contract: PASS'

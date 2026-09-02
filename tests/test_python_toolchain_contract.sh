#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOST_MANIFEST="$ROOT/manifests/packages-system.txt"
SYSTEM_VALIDATION="$ROOT/modules/system/09_system_validation.sh"
UBUNTU_BOOT="$ROOT/guest/ubuntu-devops/bootstrap-devops.sh"
UBUNTU_VERIFY="$ROOT/guest/ubuntu-devops/verify-devops.sh"

for pkg in python3 python3-pip python3-devel pipx; do
  grep -Fxq "$pkg" "$HOST_MANIFEST" || { echo "host Python package missing from system manifest: $pkg" >&2; exit 1; }
done
for token in 'rpm -q python3 python3-pip python3-devel pipx' 'python3 -m pip --version' 'python3 -m venv'; do
  grep -Fq "$token" "$SYSTEM_VALIDATION" || { echo "host Python postcheck missing: $token" >&2; exit 1; }
done

for pkg in python3 python3-pip python3-venv pipx; do
  grep -Fq "$pkg" "$UBUNTU_BOOT" || { echo "Ubuntu Python package missing from bootstrap: $pkg" >&2; exit 1; }
done
for token in python3 pip3 pipx python.venv 'python3 -m pip --version' 'python3 -m venv'; do
  grep -Fq "$token" "$UBUNTU_VERIFY" || { echo "Ubuntu Python verification missing: $token" >&2; exit 1; }
done

echo 'python toolchain contract: PASS'

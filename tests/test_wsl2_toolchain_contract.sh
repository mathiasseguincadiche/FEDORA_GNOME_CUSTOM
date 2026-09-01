#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
doctor="$ROOT/diagnostics/wsl2-doctor"
doc="$ROOT/docs/WSL2_VALIDATION.md"

[[ -f "$doctor" ]] || { echo 'missing diagnostics/wsl2-doctor' >&2; exit 1; }
[[ -f "$doc" ]] || { echo 'missing docs/WSL2_VALIDATION.md' >&2; exit 1; }

# Fedora WSL can be intentionally minimal. Every command used by the doctor
# before deeper validation must be part of the explicit preflight contract.
grep -Fq 'for cmd in bash dnf rpm git grep awk free lscpu lsblk findmnt systemctl' "$doctor"
grep -Fq "emit KO 'Core tools'" "$doctor"
grep -Fq 'INSTALL MISSING CORE TOOLS' "$doctor"
grep -Fq "emit OK 'Core tools'" "$doctor"

preflight_line="$(grep -n '^for cmd in bash dnf rpm git grep awk free lscpu lsblk findmnt systemctl' "$doctor" | head -n1 | cut -d: -f1)"
runtime_line="$(grep -n '^if runtime_is_wsl2' "$doctor" | head -n1 | cut -d: -f1)"
mem_line="$(grep -n '^mem_visible=' "$doctor" | head -n1 | cut -d: -f1)"
[[ "$preflight_line" =~ ^[0-9]+$ && "$runtime_line" =~ ^[0-9]+$ && "$mem_line" =~ ^[0-9]+$ ]]
[[ "$preflight_line" -lt "$runtime_line" && "$preflight_line" -lt "$mem_line" ]] || {
  echo 'WSL2 core-tool preflight must run before runtime/memory checks use external commands' >&2
  exit 1
}

# The operator runbook must install the Fedora package that provides awk and
# explain the package-to-command mapping.
grep -Fq 'gawk' "$doc"
grep -Eq 'gawk.*fournit.*awk' "$doc"
grep -Fq 'procps-ng' "$doc"
grep -Fq 'util-linux' "$doc"
grep -Fq 'KO Core tools' "$doc"

echo 'WSL2 toolchain contract: PASS'

#!/usr/bin/env bash
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_ROOT/reports/$(date -u +%Y%m%dT%H%M%SZ)-previous-boot-failure.txt"
{
  echo '[previous boot warnings/errors]'; journalctl -b -1 -p warning..alert --no-pager 2>&1 || true
  echo '[previous kernel xe/drm/acpi/aer/nvme]'; journalctl -k -b -1 --no-pager 2>&1 | grep -Ei 'xe|drm|amdgpu|ACPI|AER:|PCIe Bus Error|nvme|MCE|EDAC|watchdog|panic|oops' || true
  echo '[coredumps]'; coredumpctl list --no-pager 2>&1 || true
  echo '[pstore]'; ls -la /sys/fs/pstore 2>&1 || true; grep -R . /sys/fs/pstore 2>/dev/null || true
  echo '[failed units]'; systemctl --failed --no-pager 2>&1 || true
} > "$OUT"
echo "$OUT"

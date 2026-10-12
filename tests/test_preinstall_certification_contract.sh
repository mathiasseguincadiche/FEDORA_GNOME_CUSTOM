#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
graphics="$ROOT/diagnostics/graphics-doctor"
kernel="$ROOT/diagnostics/kernel-doctor"
final="$ROOT/diagnostics/final-certification"
for file in "$graphics" "$kernel" "$final"; do bash -n "$file"; done
grep -Fq -- '--certify) certify=true' "$graphics"
grep -Fq -- '--certify) certify=true' "$kernel"
grep -Fq "check KO Vulkan 'Intel Vulkan acceleration is required for physical certification'" "$graphics"
grep -Fq "check KO VA-API 'B580 render-node acceleration is required for physical certification'" "$graphics"
grep -Fq "check KO Wayland" "$graphics"
grep -Fq "emit KO 'N-1' 'no rollback kernel installed" "$kernel"
grep -Fq 'diagnostics/graphics-doctor" --quiet --certify' "$final"
grep -Fq 'diagnostics/kernel-doctor" --quiet --certify' "$final"
echo 'PASS: final certification requires physical GPU acceleration and N-1 rollback'

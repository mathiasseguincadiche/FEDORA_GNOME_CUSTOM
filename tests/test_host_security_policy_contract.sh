#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
policy="$ROOT/config/golden-host.policy"
doctor="$ROOT/diagnostics/host-security-policy-doctor"
kickstart="$ROOT/installer/generate-fedora44-kickstart.sh"

[[ -r "$policy" ]]
grep -Fxq 'HOST_SECURE_BOOT_POLICY=disabled-required' "$policy"
grep -Fxq 'HOST_STORAGE_ENCRYPTION_POLICY=forbidden' "$policy"
grep -Fxq 'HOST_LUKS_POLICY=forbidden' "$policy"

[[ -r "$doctor" ]]
grep -Fq "mokutil --sb-state" "$doctor"
grep -Fq "lsblk -nr -o TYPE" "$doctor"
grep -Fq '/etc/crypttab' "$doctor"
grep -Fq 'dmsetup table --target crypt' "$doctor"

grep -Fq 'autopart --type=btrfs' "$kickstart"
if grep -Eqi -- 'autopart[^[:cntrl:]]*--encrypted|cryptsetup[[:space:]].*(luksFormat|luksOpen|open)|luks2|--luks-version' "$kickstart"; then
  echo 'Kickstart must never introduce local disk encryption on the Golden HOST' >&2
  exit 1
fi

# Mutating project code must not gain a local block-encryption path. Policy/docs/tests
# are intentionally excluded because they need to describe and verify the prohibition.
while IFS= read -r file; do
  if grep -Eqi -- 'cryptsetup[[:space:]].*(luksFormat|luksOpen|open)|autopart[^[:cntrl:]]*--encrypted|--luks-version' "$file"; then
    echo "Forbidden local disk-encryption implementation detected: ${file#"$ROOT"/}" >&2
    exit 1
  fi
done < <(find "$ROOT/installer" "$ROOT/modules" "$ROOT/scripts" -type f -print)

grep -Fq 'host-security-policy-doctor" --quiet' "$ROOT/diagnostics/final-certification"
grep -Fq 'host-security-policy-doctor" --quiet' "$ROOT/diagnostics/workstation-doctor"
grep -Fq 'test_host_security_policy_contract.sh' "$ROOT/.github/workflows/tests.yml"

printf 'PASS: Golden HOST forbids Secure Boot and local disk encryption\n'

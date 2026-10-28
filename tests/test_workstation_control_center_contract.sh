#!/usr/bin/env bash
# Control Center specification: version format, retention policy, the thin
# facade rule and the archive-sealing safeguards (not yet behaviour-tested).
# Routing, dashboard states and retention run in test_control_center_behavior.sh;
# the update order in test_update_dispatch_behavior.sh.
# shellcheck disable=SC2016
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail() { echo "workstation control center contract: FAIL: $*" >&2; exit 1; }

version="$(tr -d '[:space:]' < "$ROOT/VERSION")"
[[ "$version" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]] || fail 'VERSION must be semantic x.y.z'

for setting in logs_days=90 reports_days=180 preserve_state=true preserve_releases=true; do
  grep -Fxq "$setting" "$ROOT/config/operator-retention.policy" || fail "retention policy missing: $setting"
done

# Thin facade: package, backup and firewall mutations stay in their engines.
if grep -Eq 'apply_gate_open|dnf5?[[:space:]].*upgrade|flatpak[[:space:]]+update|borg[[:space:]]+(create|prune|compact|delete)|nft[[:space:]]+-f' \
  "$ROOT/control.sh" "$ROOT/lib/control_center.sh" "$ROOT/lib/control_center_presentation.sh"; then
  fail 'business logic leaked into the Control Center'
fi

# Long-term archive sealing: certified bare-metal release only, payloads kept
# out of the checkout, nothing downloaded.
seal="$ROOT/scripts/release/seal-golden-archive.sh"
for token in 'runtime_is_baremetal' "grep -Fxq 'verdict=PASS'" 'fingerprint=$(workstation_runtime_fingerprint)' \
  'effective_config_sha256=$(effective_config_sha256)' 'Destination must not be inside a payload source' \
  'MANIFEST.sha256' 'must be stored outside the Git checkout'; do
  grep -Fq "$token" "$seal" || fail "archive sealing safeguard missing: $token"
done
if grep -Eq '(curl|wget)[[:space:]]' "$seal"; then fail 'archive sealing downloads payloads'; fi

echo 'workstation control center contract: PASS'

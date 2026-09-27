#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
source "$ROOT/lib/mutations.sh"
log_error() { :; }
run_mutating() { printf '%s\n' "$*" >> "$tmp/calls"; return "${test_command_rc:-0}"; }
rc=0
install_manifest_packages TEST "$tmp/missing" || rc=$?
[[ "$rc" == 60 && ! -e "$tmp/calls" ]]
printf '# empty manifest\n\n' > "$tmp/empty"
install_manifest_packages TEST "$tmp/empty"
[[ ! -e "$tmp/calls" ]]
printf '# packages\npython3\njq\n' > "$tmp/packages"
install_manifest_packages TEST "$tmp/packages"
[[ "$(cat "$tmp/calls")" == 'TEST sudo dnf -y install python3 jq' ]]
test_command_rc=43
rc=0
install_manifest_packages TEST "$tmp/packages" || rc=$?
[[ "$rc" == 43 ]]
echo 'package manifest behavior: PASS'

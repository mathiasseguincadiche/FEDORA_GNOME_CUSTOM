#!/usr/bin/env bash
# T705 SMART health read for real with a fake smartctl that behaves like the
# real one: -j prints a JSON document whatever its exit status, a bit mask that
# is non-zero without root (open failed, no SMART log) and when the NVMe error
# log has entries. Exactly one usable document must reach the health policy.
# shellcheck disable=SC2016,SC1090,SC1091
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "storage health behavior: FAIL: $*" >&2; exit 1; }
mkdir -p "$tmp/bin"
export T_LOG="$tmp/calls" T_TMP="$tmp"

fake() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$tmp/bin/$1"; chmod +x "$tmp/bin/$1"; }
# smartctl: as a normal user the device cannot be opened (rc=2, no SMART log);
# as root it returns the log, with bit 6 when the error log has entries.
fake smartctl 'printf "smartctl %s root=%s\n" "$*" "${T_ROOT:-0}" >> "$T_LOG"
if [[ "${T_ROOT:-0}" != 1 && -z "${T_USER_READABLE:-}" ]]; then
  printf "{\"smartctl\": {\"exit_status\": 2, \"messages\": [{\"string\": \"Permission denied\"}]}}\n"; exit 2
fi
cat <<JSON
{"smartctl": {"exit_status": ${T_RC:-64}},
 "nvme_smart_health_information_log": {"critical_warning": ${T_CRITICAL:-0}, "temperature": 41,
  "available_spare": 100, "available_spare_threshold": 5, "percentage_used": 1,
  "media_errors": ${T_MEDIA:-0}, "num_err_log_entries": ${T_ERRLOG:-12}}}
JSON
exit "${T_RC:-64}"'
fake sudo '[[ "$1" == -n ]] && shift; [[ -z "${T_NO_SUDO:-}" ]] || exit 1; T_ROOT=1 exec "$@"'
export PATH="$tmp/bin:$PATH"

baseline_hw_value() { if [[ -r "$1" ]]; then head -n1 "$1"; else printf '%s\n' "${2:-unknown}"; fi; }
source "$ROOT/lib/hardware_profile.sh"
source "$ROOT/lib/storage_health.sh"
storage_nvme_pcie_validate() { return 0; }   # PCIe links are exercised in test_hardware_kvm_behavior.sh

summary_of() { storage_nvme_health_json /dev/nvme0 | storage_nvme_health_summary; }

# Normal user: the unreadable first answer is dropped, the root answer (rc=64) is kept alone.
rm -f "$T_LOG"
json="$(storage_nvme_health_json /dev/nvme0)" || fail 'SMART health refused for a normal user with sudo'
[[ "$(grep -c '"smartctl"' <<<"$json")" == 1 ]] || fail "more than one smartctl document returned: $json"
[[ "$(paste -sd'|' "$T_LOG")" == 'smartctl -a -j /dev/nvme0 root=0|smartctl -a -j /dev/nvme0 root=1' ]] || fail "unexpected smartctl calls: $(paste -sd'|' "$T_LOG")"
grep -Fxq 'error_log_entries=12' <<<"$(summary_of)" || fail 'SMART summary not readable from the sudo answer'
storage_nvme_validate_controller /dev/nvme0 || fail 'healthy T705 with error log entries refused'

# Readable without root (rc=64 because of the error log): used directly, no sudo.
rm -f "$T_LOG"
T_USER_READABLE=1 storage_nvme_health_json /dev/nvme0 >/dev/null || fail 'readable SMART answer with rc=64 refused'
[[ "$(paste -sd'|' "$T_LOG")" == 'smartctl -a -j /dev/nvme0 root=0' ]] || fail "sudo used although the first answer was usable: $(paste -sd'|' "$T_LOG")"
T_USER_READABLE=1 T_RC=0 storage_nvme_validate_controller /dev/nvme0 || fail 'clean SMART answer refused'

# No usable answer at all: refused, never a merged or empty document.
if T_NO_SUDO=1 storage_nvme_health_json /dev/nvme0 >/dev/null; then fail 'SMART health accepted without any SMART log'; fi
if T_NO_SUDO=1 storage_nvme_validate_controller /dev/nvme0; then fail 'controller validated without a SMART log'; fi

# The health policy still refuses real faults read through sudo.
if T_CRITICAL=1 storage_nvme_validate_controller /dev/nvme0; then fail 'critical warning accepted'; fi
if T_MEDIA=3 storage_nvme_validate_controller /dev/nvme0; then fail 'media errors accepted'; fi

echo 'storage health behavior: PASS'

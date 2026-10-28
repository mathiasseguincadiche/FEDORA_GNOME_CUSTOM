#!/usr/bin/env bash
# Real dispatcher of scripts/maintenance/update-system.sh with its engines
# recorded: the full backup runs before any DNF preparation and a failed
# backup stops the update, mutations are bare-metal only, and firmware is only
# ever queried. The offline transaction itself is covered by
# test_update_kernel_deferral_behavior.sh.
# shellcheck disable=SC2317,SC2329,SC2034
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "update dispatch behavior: FAIL: $*" >&2; exit 1; }
script="$ROOT/scripts/maintenance/update-system.sh"
export T_LOG="$tmp/calls"
mkdir -p "$tmp/bin" "$tmp/root/scripts/backup"
cat > "$tmp/bin/fwupdmgr" <<'SH'
#!/usr/bin/env bash
printf 'fwupdmgr %s\n' "$*" >> "$T_LOG"
SH
cat > "$tmp/root/scripts/backup/backup-now.sh" <<'SH'
#!/usr/bin/env bash
printf 'backup\n' >> "$T_LOG"
exit "${T_BACKUP_RC:-0}"
SH
chmod +x "$tmp/bin/fwupdmgr" "$tmp/root/scripts/backup/backup-now.sh"
dispatcher="$(sed -n '/^mode="\${1:---check}"$/,$p' "$script")"
[[ -n "$dispatcher" ]] || fail 'cannot find the update-system.sh dispatcher'

# dispatch MODE: run the real dispatcher in a subshell; prints its exit code.
dispatch() {
  : > "$T_LOG"
  local rc
  # Not under `||`: errexit must stay active inside, as in production.
  set +e
  (
    set -e
    export PATH="$tmp/bin:$PATH"
    STATE_ROOT="$tmp/state"; REPORT_ROOT="$tmp/reports"; LOG_DIR="$tmp/logs"; MAIN_LOG="$LOG_DIR/main.log"
    # shellcheck disable=SC1090
    source <(sed -e 's/^engine_bootstrap$/engine_load_libraries; config_load/' -e '/^mode="\${1:---check}"$/,$d' \
      -e "s|^REPO_ROOT=.*|REPO_ROOT='$ROOT'|" "$script")
    REPO_ROOT="$tmp/root"
    RUNTIME_ENVIRONMENT="${T_RUNTIME:-baremetal}"
    runtime_is_baremetal() { [[ "$RUNTIME_ENVIRONMENT" == baremetal ]]; }
    require_fedora() { :; }
    record() { printf '%s\n' "$*" >> "$T_LOG"; }
    prepare_dnf_offline() { record "prepare $1"; }
    request_offline_reboot() { record reboot; }
    finalize_offline_update() { record finalize; }
    apply_flatpak() { record flatpak; }
    check_dnf() { :; }; check_kernel() { :; }; check_flatpak() { :; }; show_offline_status() { :; }
    set -- "$1"
    eval "$dispatcher"
  ) > "$tmp/out" 2>&1
  rc=$?
  set -e
  printf '%s\n' "$rc"
}
calls() { paste -sd'|' "$T_LOG"; }

# A full backup precedes the DNF offline preparation, for both update modes.
[[ "$(dispatch --apply)" == 0 && "$(calls)" == 'backup|prepare full' ]] || fail "--apply ran: $(calls)"
[[ "$(dispatch --dnf-only)" == 0 && "$(calls)" == 'backup|prepare dnf-only' ]] || fail "--dnf-only ran: $(calls)"

# A failed backup stops the update before DNF.
for mode in --apply --dnf-only; do
  rc="$(T_BACKUP_RC=40 dispatch "$mode")"
  [[ "$rc" != 0 && "$(calls)" == backup ]] || fail "$mode continued after a failed backup (rc=$rc): $(calls)"
done

# Every mutation is refused outside bare metal, before any work.
for mode in --apply --dnf-only --offline-reboot --finalize --flatpak-only; do
  rc="$(T_RUNTIME=vm dispatch "$mode")"
  [[ "$rc" == 50 && ! -s "$T_LOG" ]] || fail "$mode ran in a VM (rc=$rc): $(calls)"
done
[[ "$(dispatch --offline-reboot)" == 0 && "$(calls)" == reboot ]] || fail 'offline reboot not routed'
[[ "$(dispatch --finalize)" == 0 && "$(calls)" == finalize ]] || fail 'finalize not routed'
[[ "$(dispatch --flatpak-only)" == 0 && "$(calls)" == flatpak ]] || fail 'Flatpak update not routed'

# Firmware is queried, never flashed, including from the read-only overview.
for mode in --firmware-check --check; do
  [[ "$(T_RUNTIME=vm dispatch "$mode")" == 0 ]] || fail "$mode failed"
  [[ "$(calls)" == 'fwupdmgr get-updates --no-metadata-check' ]] || fail "$mode ran: $(calls)"
done

[[ "$(dispatch --bogus)" == 2 && ! -s "$T_LOG" ]] || fail 'unknown mode was not a usage error'

echo 'update dispatch behavior: PASS'

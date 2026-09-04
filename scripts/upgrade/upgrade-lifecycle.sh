#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
# shellcheck disable=SC1091
source "$REPO_ROOT/config/fedora-upgrade.policy"
# shellcheck disable=SC1091
source "$REPO_ROOT/lib/fedora-upgrade-qualification.sh"

upgrade_state_dir() { printf '%s/upgrade' "$STATE_ROOT"; }
upgrade_marker() { printf '%s/qualified-%s.ok' "$(upgrade_state_dir)" "$1"; }
upgrade_prepared_marker() { printf '%s/prepared-%s.ok' "$(upgrade_state_dir)" "$1"; }
upgrade_report() { printf '%s/fedora-%s-qualification.txt' "$REPORT_ROOT" "$1"; }
upgrade_ensure_dirs() { mkdir -p "$(upgrade_state_dir)" "$REPORT_ROOT"; }

fedora_release() {
  awk -F= '$1=="VERSION_ID" {gsub(/"/,"",$2); print $2; exit}' /etc/os-release 2>/dev/null || true
}

valid_target() {
  local target="$1" source
  [[ "$target" =~ ^[0-9]+$ ]] || return 1
  source="$(fedora_release)"
  [[ "$source" =~ ^[0-9]+$ ]] || return 1
  (( target == source + ${FEDORA_UPGRADE_MAX_HOPS:-1} ))
  [[ "$source" == "${FEDORA_UPGRADE_SOURCE_RELEASE:-44}" ]]
  [[ "$target" == "${FEDORA_UPGRADE_TARGET_RELEASE:-45}" ]]
}

final_release_url() {
  local target="$1" configured="${FEDORA_UPGRADE_FINAL_RELEASE_URL:-}"
  if [[ "$target" == "${FEDORA_UPGRADE_TARGET_RELEASE:-45}" && -n "$configured" ]]; then
    printf '%s\n' "$configured"
  else
    printf 'https://download.fedoraproject.org/pub/fedora/linux/releases/%s/\n' "$target"
  fi
}

final_release_available() {
  local target="$1"
  command_exists curl || return 1
  curl -fsSL --connect-timeout 10 --max-time 30 -o /dev/null "$(final_release_url "$target")"
}

current_gold_cert_valid() {
  local cert="$STATE_ROOT/final/certified.ok" fp
  [[ -s "$cert" ]] || return 1
  grep -Fxq 'verdict=PASS' "$cert" || return 1
  fp="$(workstation_runtime_fingerprint)"
  grep -Fxq "fingerprint=$fp" "$cert"
}

qualification_fresh() {
  local target="$1" marker age now ts max_hours
  marker="$(upgrade_marker "$target")"
  [[ -s "$marker" ]] || return 1
  grep -Fxq 'mechanism_status=PASS' "$marker" || return 1
  grep -Fxq 'readiness=READY' "$marker" || return 1
  grep -Fxq 'verdict=PASS' "$marker" || return 1
  grep -Fxq "source_release=${FEDORA_UPGRADE_SOURCE_RELEASE:-44}" "$marker" || return 1
  grep -Fxq "target_release=$target" "$marker" || return 1
  grep -Fxq "project_commit=$(repo_commit)" "$marker" || return 1
  ts="$(stat -c %Y "$marker")"
  now="$(date +%s)"
  max_hours="${FEDORA_UPGRADE_QUALIFICATION_MAX_AGE_HOURS:-168}"
  age=$((now-ts))
  (( age >= 0 && age <= max_hours*3600 ))
}

repo_query_lines() {
  local mode="$1"
  dnf5 -q repoquery "--$mode" 2>/dev/null || true
}

write_inventory() {
  local target="$1" report="$2"
  {
    printf 'Fedora Golden major-upgrade qualification\n'
    printf 'project_commit=%s\n' "$(repo_commit)"
    printf 'source_release=%s\n' "$(fedora_release)"
    printf 'target_release=%s\n' "$target"
    printf 'runtime=%s\n' "$(runtime_environment)"
    printf 'generated_utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'final_release_url=%s\n' "$(final_release_url "$target")"
    if final_release_available "$target"; then printf 'final_release_available=yes\n'; else printf 'final_release_available=no\n'; fi
    printf '\n[enabled-repositories]\n'
    dnf5 --releasever="$target" -q repolist --enabled 2>&1 || true
    printf '\n[duplicate-packages]\n'
    repo_query_lines duplicates
    printf '\n[extra-packages]\n'
    repo_query_lines extras
    printf '\n[gnome-extension-targets]\n'
    grep -Hn "shell_version=.*50\|GNOME Shell target.*50" "$REPO_ROOT"/scripts/gnome/install-*.sh 2>/dev/null || true
  } >"$report"
}

check() {
  local target="${1:-${FEDORA_UPGRADE_TARGET_RELEASE:-45}}" report duplicates
  command_exists dnf5 || { ui_error 'dnf5 is required'; return "$EXIT_PRECHECK_FAILED"; }
  valid_target "$target" || { ui_error "Only the validated one-hop path ${FEDORA_UPGRADE_SOURCE_RELEASE:-44} -> ${FEDORA_UPGRADE_TARGET_RELEASE:-45} is allowed"; return "$EXIT_SECURITY_BLOCK"; }
  upgrade_ensure_dirs
  report="$(upgrade_report "$target")"
  write_inventory "$target" "$report"
  duplicates="$(repo_query_lines duplicates)"
  ui_banner 'FEDORA N+1' "CHECK ${FEDORA_UPGRADE_SOURCE_RELEASE:-44} -> $target"
  ui_meta 'Current release' "$(fedora_release)"
  ui_meta 'Target release' "$target"
  ui_meta 'Final release' "$(final_release_available "$target" && printf available || printf not-published)"
  if [[ -z "$duplicates" ]]; then ui_check OK duplicates none; else ui_check WARN duplicates 'installed duplicates detected; see report'; fi
  ui_check OK Report "$report"
}

qualify() {
  local target="${1:-${FEDORA_UPGRADE_TARGET_RELEASE:-45}}" report txdir duplicates closure_status blockers=0 marker
  check "$target"
  command_exists dnf5 || return "$EXIT_PRECHECK_FAILED"
  command_exists jq || { ui_error 'jq is required'; return "$EXIT_PRECHECK_FAILED"; }
  upgrade_ensure_dirs
  report="$(upgrade_report "$target")"
  marker="$(upgrade_marker "$target")"
  txdir="$(mktemp -d)"
  trap 'rm -rf "$txdir"' RETURN

  if ! duplicates="$(dnf5 -q repoquery --duplicates)"; then
    ui_error 'Unable to query installed duplicate RPMs'
    return "$EXIT_PRECHECK_FAILED"
  fi
  if [[ -n "$duplicates" ]]; then
    {
      printf '\n[blocker]\n'
      printf 'Installed duplicate RPMs block Fedora N+1 qualification.\n'
    } >>"$report"
    blockers=$((blockers+1))
  fi

  ui_check OK 'Target metadata' "refreshing Fedora $target repositories"
  dnf5 --releasever="$target" -y makecache --refresh

  ui_check OK 'Repository closure' "Fedora $target"
  if ! fedora_upgrade_repoclosure_probe "$target" "$txdir/repoclosure.json" "$txdir/repoclosure.err" "$txdir/repoclosure.status"; then
    ui_error 'repoclosure mechanism failed or produced an invalid report'
    cat "$txdir/repoclosure.err" >&2 || true
    return "$EXIT_PRECHECK_FAILED"
  fi
  closure_status="$(<"$txdir/repoclosure.status")"
  {
    printf '\n[repository-closure]\n'
    cat "$txdir/repoclosure.json"
  } >>"$report"

  if [[ "$closure_status" == BLOCKED ]]; then
    {
      printf '\n[blocker]\n'
      printf 'Fedora %s repositories contain unresolved dependencies; see repository-closure.\n' "$target"
    } >>"$report"
    blockers=$((blockers+1))
  else
    ui_check OK 'Transaction resolution' 'distro-sync transaction is stored, not executed'
    dnf5 --releasever="$target" distro-sync --store="$txdir/transaction"
  fi

  # Current Golden desktop extensions are intentionally pinned to the running
  # GNOME major. A major Fedora qualification must not silently assume they work
  # on the next GNOME major.
  if grep -Eq "shell_version=.*50|GNOME Shell target.*50" "$REPO_ROOT"/scripts/gnome/install-*.sh; then
    {
      printf '\n[blocker]\n'
      printf 'Current reviewed GNOME extension artifacts are pinned to GNOME Shell 50.\n'
      printf 'Fedora 45 / GNOME 51 compatibility must be explicitly repinned and reviewed before qualification can pass.\n'
    } >>"$report"
    blockers=$((blockers+1))
  fi

  if (( blockers == 0 )); then
    {
      printf 'mechanism_status=PASS\n'
      printf 'readiness=READY\n'
      printf 'verdict=PASS\n'
      printf 'source_release=%s\n' "$(fedora_release)"
      printf 'target_release=%s\n' "$target"
      printf 'project_commit=%s\n' "$(repo_commit)"
      printf 'qualified_utc=%s\n' "$(date -u +%FT%TZ)"
      printf 'final_release_available=%s\n' "$(final_release_available "$target" && printf yes || printf no)"
    } >"$marker"
    ui_check OK 'Fedora N+1 qualification' "PASS marker=$marker"
  else
    {
      printf 'mechanism_status=PASS\n'
      printf 'readiness=BLOCKED\n'
      printf 'verdict=BLOCKED\n'
      printf 'blockers=%d\n' "$blockers"
      printf 'source_release=%s\n' "$(fedora_release)"
      printf 'target_release=%s\n' "$target"
      printf 'project_commit=%s\n' "$(repo_commit)"
      printf 'qualified_utc=%s\n' "$(date -u +%FT%TZ)"
      printf 'final_release_available=%s\n' "$(final_release_available "$target" && printf yes || printf no)"
    } >"$marker"
    ui_check WARN 'Fedora N+1 qualification' "BLOCKED blockers=$blockers report=$report"
  fi
}

prepare() {
  local target="${1:-${FEDORA_UPGRADE_TARGET_RELEASE:-45}}" rc=0
  runtime_is_baremetal || { ui_error 'Major Fedora upgrade preparation is bare-metal only'; return "$EXIT_SECURITY_BLOCK"; }
  valid_target "$target" || { ui_error 'Invalid major-upgrade target'; return "$EXIT_SECURITY_BLOCK"; }
  "$REPO_ROOT/diagnostics/host-security-policy-doctor" --quiet || { ui_error 'Golden HOST policy is not compliant'; return "$EXIT_SECURITY_BLOCK"; }
  if is_true "${FEDORA_UPGRADE_REQUIRE_CLEAN_GIT:-true}"; then apply_gate_require_clean_git || { ui_error 'Git working tree must be clean'; return "$EXIT_SECURITY_BLOCK"; }; fi
  if is_true "${FEDORA_UPGRADE_REQUIRE_BASELINE:-true}"; then apply_gate_require_baseline || { ui_error 'Valid hardware baseline required'; return "$EXIT_PRECHECK_FAILED"; }; fi
  if is_true "${FEDORA_UPGRADE_REQUIRE_CURRENT_GOLDEN_CERT:-true}"; then current_gold_cert_valid || { ui_error 'Current Fedora Golden certification is missing/stale'; return "$EXIT_PRECHECK_FAILED"; }; fi
  if is_true "${FEDORA_UPGRADE_REQUIRE_PREAPPLY_BACKUP:-true}"; then apply_gate_require_backup || { ui_error 'Fresh same-commit Restic backup + restore-canary proof required'; return "$EXIT_PRECHECK_FAILED"; }; fi
  if is_true "${FEDORA_UPGRADE_REQUIRE_QUALIFICATION:-true}"; then qualification_fresh "$target" || { ui_error 'Fresh same-commit N+1 qualification marker required'; return "$EXIT_PRECHECK_FAILED"; }; fi
  if is_true "${FEDORA_UPGRADE_REQUIRE_FINAL_RELEASE:-true}"; then final_release_available "$target" || { ui_error "Fedora $target final release is not published; preparation is intentionally blocked"; return "$EXIT_PRECHECK_FAILED"; }; fi
  command_exists dnf5 || return "$EXIT_PRECHECK_FAILED"
  dnf5 system-upgrade --help >/dev/null 2>&1 || { ui_error 'dnf5 system-upgrade plugin is unavailable'; return "$EXIT_PRECHECK_FAILED"; }
  command_exists needs-restarting || { ui_error 'needs-restarting is required before major-upgrade preparation'; return "$EXIT_PRECHECK_FAILED"; }

  if ! needs-restarting -r >/dev/null 2>&1; then
    ui_error 'Current Fedora requires a reboot before major-upgrade preparation'
    return "$EXIT_PRECHECK_FAILED"
  fi

  if dnf5 -q check-upgrade >/dev/null 2>&1; then :; else
    rc=$?
    if (( rc == 100 )); then ui_error 'Apply ordinary Fedora 44 updates before preparing the major upgrade'; return "$EXIT_PRECHECK_FAILED"; fi
    (( rc == 0 )) || { ui_error "Unable to establish ordinary update state (rc=$rc)"; return "$EXIT_PRECHECK_FAILED"; }
  fi

  if is_true "${FEDORA_UPGRADE_ALLOW_ALLERASING:-false}"; then
    ui_error '--allowerasing is forbidden by the current Golden policy'
    return "$EXIT_SECURITY_BLOCK"
  fi

  ui_banner 'FEDORA MAJOR UPGRADE' "PREPARE ${FEDORA_UPGRADE_SOURCE_RELEASE:-44} -> $target"
  sudo dnf5 system-upgrade download --releasever="$target"
  upgrade_ensure_dirs
  {
    printf 'verdict=PREPARED\n'
    printf 'source_release=%s\n' "$(fedora_release)"
    printf 'target_release=%s\n' "$target"
    printf 'project_commit=%s\n' "$(repo_commit)"
    printf 'prepared_utc=%s\n' "$(date -u +%FT%TZ)"
    printf 'automatic_reboot=false\n'
  } >"$(upgrade_prepared_marker "$target")"
  ui_check OK 'Offline transaction' 'downloaded and prepared; NOT rebooted'
  printf '\nReview the transaction and backups. The project never auto-reboots into a major upgrade.\n'
  printf 'When deliberately approved by the operator, the DNF command is: sudo dnf5 system-upgrade reboot\n'
}

postcheck() {
  local target="${1:-${FEDORA_UPGRADE_TARGET_RELEASE:-45}}" cert="$STATE_ROOT/final/certified.ok"
  [[ "$(fedora_release)" == "$target" ]] || { ui_error "Running Fedora $(fedora_release), expected $target"; return "$EXIT_POSTCHECK_FAILED"; }
  "$REPO_ROOT/diagnostics/host-security-policy-doctor" --quiet
  dnf5 check
  if [[ -n "$(repo_query_lines duplicates)" ]]; then ui_error 'Duplicate RPMs detected after major upgrade'; return "$EXIT_POSTCHECK_FAILED"; fi
  if [[ -s "$cert" ]] && grep -Fxq "fingerprint=$(workstation_runtime_fingerprint)" "$cert"; then
    ui_error 'Old Golden certificate unexpectedly remains valid after a major Fedora release change'
    return "$EXIT_POSTCHECK_FAILED"
  fi
  ui_check OK 'Post-upgrade state' "Fedora $target running; old Golden evidence is invalidated as required"
  printf 'Run the full bare-metal baseline/runtime certification before declaring Fedora %s Golden.\n' "$target"
}

status() {
  local target="${1:-${FEDORA_UPGRADE_TARGET_RELEASE:-45}}"
  ui_banner 'FEDORA MAJOR UPGRADE' 'GOLDEN LIFECYCLE'
  ui_meta Source "$(fedora_release)"
  ui_meta Target "$target"
  ui_meta 'Final release URL' "$(final_release_url "$target")"
  if final_release_available "$target"; then ui_check OK 'Final release' available; else ui_check WARN 'Final release' not-published; fi
  if qualification_fresh "$target"; then ui_check OK Qualification 'fresh PASS'; else ui_check WARN Qualification 'missing/stale/blocked'; fi
  if [[ -s "$(upgrade_prepared_marker "$target")" ]]; then ui_check WARN Prepared 'offline transaction marker present'; else ui_check OK Prepared none; fi
}

clean() {
  runtime_is_baremetal || { ui_error 'Cleanup is bare-metal only'; return "$EXIT_SECURITY_BLOCK"; }
  command_exists dnf5 || return "$EXIT_PRECHECK_FAILED"
  sudo dnf5 system-upgrade clean
  rm -f "$(upgrade_prepared_marker "${1:-${FEDORA_UPGRADE_TARGET_RELEASE:-45}}")"
  ui_check OK 'Offline transaction' cleaned
}

usage() {
  cat <<'EOF'
Usage: upgrade-lifecycle.sh status|check|qualify|prepare|postcheck|clean [release]

check      Read-only inventory/report for Fedora N+1.
qualify    Resolve N+1 repositories and a stored distro-sync transaction; never upgrades RPMs.
prepare    Bare-metal only. Requires Golden cert + baseline + same-commit Restic restore-canary + final release; downloads only.
postcheck  Verify the new release and require Golden evidence invalidation.
clean      Remove a prepared DNF offline-upgrade transaction.

There is deliberately no automatic reboot/upgrade command in this project.
EOF
}

case "${1:-status}" in
  status) status "${2:-}" ;;
  check) check "${2:-}" ;;
  qualify) qualify "${2:-}" ;;
  prepare) prepare "${2:-}" ;;
  postcheck) postcheck "${2:-}" ;;
  clean) clean "${2:-}" ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit "$EXIT_USAGE" ;;
esac

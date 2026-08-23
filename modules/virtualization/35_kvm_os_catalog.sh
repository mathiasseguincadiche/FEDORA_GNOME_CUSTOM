#!/usr/bin/env bash
set -Eeuo pipefail

kvm_catalog_precheck() {
  is_true "${ENABLE_KVM:-true}" || return 0
  is_true "${KVM_REQUIRE_OSINFO:-true}" || return 0
  command_exists dnf || return "$EXIT_PRECHECK_FAILED"
}

kvm_catalog_plan() {
  cat <<'EOF'
GUEST OS CATALOG:
- use Fedora osinfo-db/libosinfo metadata instead of a project-maintained stale OS database
- validate osinfo-query and virt-install OS detection support
- allow install media detection with require=off when a brand-new release is newer than packaged osinfo-db
- keep Ubuntu Server LTS, Fedora and Windows 11 as explicit project profiles
- never download installation media automatically from this module
EOF
}

kvm_catalog_apply() { :; }

kvm_catalog_postcheck() {
  local catalog
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KVM:-true}" || return 0
  is_true "${KVM_REQUIRE_OSINFO:-true}" || return 0
  command_exists osinfo-query || return "$EXIT_POSTCHECK_FAILED"
  catalog="$(osinfo-query os 2>/dev/null || true)"
  [[ -n "$catalog" ]] || { log_error KVM 'libosinfo catalog is empty'; return "$EXIT_POSTCHECK_FAILED"; }
  grep -Eqi 'Fedora|fedora' <<<"$catalog" || log_warn KVM 'Fedora entry not matched in current osinfo-db'
  grep -Eqi 'Ubuntu|ubuntu' <<<"$catalog" || log_warn KVM 'Ubuntu entry not matched in current osinfo-db'
  grep -Eqi 'Windows 11|win11' <<<"$catalog" || log_warn KVM 'Windows 11 entry not matched in current osinfo-db'
}

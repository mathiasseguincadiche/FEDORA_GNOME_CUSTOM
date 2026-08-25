#!/usr/bin/env bash
set -Eeuo pipefail

backup_preflight_precheck() {
  command_exists dnf && command_exists findmnt && command_exists lsblk && command_exists df
}

backup_preflight_plan() {
  cat <<'EOF'
BACKUP / RECOVERY PRECHECK:
- Restic is the only managed backup engine and encryption is mandatory
- pre-APPLY backup must live on a proven external target, never on the protected system disk
- repository/password are injected at runtime; no secret is committed
- backup marker is bound to the exact Git commit used for APPLY
- host configuration, project sources, libvirt metadata and optional VM disks have separate capture rules
- live qcow2 file copies are forbidden; VM disk capture requires the guest to be shut off
- integrity check and restore-canary test are mandatory before a pre-APPLY marker is accepted
- restore helpers are staging-first and never overwrite a live host automatically
EOF
}

backup_preflight_apply() {
  run_mutating BACKUP sudo dnf -y install restic jq acl tar gzip findutils || return "$EXIT_APPLY_FAILED"
}

backup_preflight_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  command_exists restic && command_exists jq && command_exists getfacl
}

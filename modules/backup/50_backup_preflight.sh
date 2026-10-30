#!/usr/bin/env bash
set -Eeuo pipefail

backup_preflight_precheck() {
  command_exists dnf && command_exists findmnt && command_exists lsblk && command_exists df
}

backup_preflight_plan() {
  cat <<'EOF'
BACKUP / RECOVERY PRECHECK:
- Borg 1.x is the only managed backup engine; the repository is unencrypted by owner decision (ADR 0014)
- pre-APPLY backup must live on a proven external target, never on the protected system disk
- the repository is chosen at runtime (config/local.conf or one external disk); there is no passphrase and no secret is committed
- backup marker is bound to the exact Git commit, configuration, module plan and hardware used for APPLY
- host configuration (/etc, /boot), GNOME user configuration and the tracked project sources are archived
- VM disks, NVRAM, TPM, cloud-init media and libvirt metadata are never archived: the owner exports them manually
- SSH and GnuPG private keys are excluded at any depth (ADR 0021)
- integrity check and restore-canary test are mandatory before a pre-APPLY marker is accepted
- restore helpers are staging-first and never overwrite a live host automatically
EOF
}

backup_preflight_apply() {
  run_mutating BACKUP sudo dnf -y install borgbackup jq acl tar gzip findutils || return "$EXIT_APPLY_FAILED"
}

backup_preflight_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  command_exists borg && command_exists jq && command_exists getfacl
}

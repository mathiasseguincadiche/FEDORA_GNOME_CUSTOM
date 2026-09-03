#!/usr/bin/env bash
set -Eeuo pipefail

backup_daily_precheck() {
  is_true "${DAILY_BACKUP_ENABLED:-true}" || return 0
  [[ -r "$REPO_ROOT/scripts/backup/daily-user-backup.sh" ]] || return "$EXIT_PRECHECK_FAILED"
}

backup_daily_plan() {
  echo 'Install a persistent user timer for encrypted daily Restic backups, bound to the Git SHA applied to the workstation; unavailable external targets are skipped without weakening pre-APPLY fail-closed backup policy.'
}

backup_daily_apply() {
  local service applied_sha
  is_true "${DAILY_BACKUP_ENABLED:-true}" || return 0
  applied_sha="$(repo_commit)"
  [[ "$applied_sha" =~ ^[0-9a-fA-F]{40}$ ]] || return "$EXIT_APPLY_FAILED"

  if is_true "${DRY_RUN:-true}"; then
    run_mutating BACKUP install -m 0755 "$REPO_ROOT/scripts/backup/daily-user-backup.sh" "$HOME/.local/libexec/fedora-gnome-daily-backup"
    return 0
  fi

  install -d -m 0755 "$HOME/.local/libexec" "$HOME/.config/systemd/user"
  install -m 0755 "$REPO_ROOT/scripts/backup/daily-user-backup.sh" "$HOME/.local/libexec/fedora-gnome-daily-backup"
  install -m 0644 "$REPO_ROOT/systemd/user/fedora-gnome-daily-backup.timer" "$HOME/.config/systemd/user/fedora-gnome-daily-backup.timer"

  service="$HOME/.config/systemd/user/fedora-gnome-daily-backup.service"
  cat > "$service" <<EOF
[Unit]
Description=Encrypted daily Fedora workstation user backup
After=network-online.target

[Service]
Type=oneshot
Environment="FEDORA_GNOME_CUSTOM_REPO=$REPO_ROOT"
Environment="FEDORA_GNOME_CUSTOM_APPLIED_SHA=$applied_sha"
ExecStart=%h/.local/libexec/fedora-gnome-daily-backup
EOF
  chmod 0644 "$service"
  systemctl --user daemon-reload
  systemctl --user enable --now fedora-gnome-daily-backup.timer
}

backup_daily_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${DAILY_BACKUP_ENABLED:-true}" || return 0
  "$REPO_ROOT/diagnostics/daily-backup-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
}

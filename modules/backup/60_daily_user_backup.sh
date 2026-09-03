#!/usr/bin/env bash
set -Eeuo pipefail

backup_daily_runtime_base() {
  printf '%s\n' "$HOME/.local/lib/fedora-gnome-custom/backup-runtime"
}

backup_daily_runtime_dir() {
  printf '%s/%s\n' "$(backup_daily_runtime_base)" "$1"
}

backup_daily_precheck() {
  is_true "${DAILY_BACKUP_ENABLED:-true}" || return 0
  for file in \
    scripts/backup/daily-user-backup.sh \
    scripts/backup/restic-retention.sh \
    lib/backup_runtime.sh \
    lib/backup_runtime_bundle.sh \
    systemd/user/fedora-gnome-daily-backup.timer; do
    [[ -r "$REPO_ROOT/$file" ]] || return "$EXIT_PRECHECK_FAILED"
  done
  [[ "${RESTIC_RETENTION_RANDOMIZED_DELAY_SEC:-1800}" =~ ^[0-9]+$ ]] || return "$EXIT_CONFIG_FAILED"
  [[ -n "${RESTIC_RETENTION_ON_CALENDAR:-}" ]] || return "$EXIT_CONFIG_FAILED"
}

backup_daily_plan() {
  echo 'Install a content-verified backup runtime bundle under ~/.local/lib/fedora-gnome-custom/backup-runtime/<applied-sha>, bind daily and weekly-retention systemd user units to that immutable bundle, and keep timer execution independent from the mutable Git checkout.'
}

backup_daily_write_config_snapshot() {
  local output="$1" var
  install -m 0600 /dev/null "$output"
  while IFS= read -r var; do
    case "$var" in
      BACKUP_*|RESTIC_*|DAILY_*) printf '%s=%q\n' "$var" "${!var}" >> "$output" ;;
    esac
  done < <(compgen -v | sort -u)
}

backup_daily_existing_runtime_valid() {
  local runtime_dir="$1" applied_sha="$2"
  [[ -d "$runtime_dir" && -r "$runtime_dir/runtime/APPLIED_SHA" && -r "$runtime_dir/MANIFEST.sha256" ]] || return 1
  [[ "$(<"$runtime_dir/runtime/APPLIED_SHA")" == "$applied_sha" ]] || return 1
  (cd "$runtime_dir" && sha256sum --check --status MANIFEST.sha256)
}

backup_daily_install_runtime() {
  local applied_sha="$1" base runtime_dir tmp rc=0
  base="$(backup_daily_runtime_base)"
  runtime_dir="$(backup_daily_runtime_dir "$applied_sha")"

  # A SHA-named runtime is immutable. Re-APPLY of the exact same commit reuses
  # a verified bundle; a corrupted/pre-existing bundle is never silently
  # overwritten because that would destroy evidence and can race a running timer.
  if [[ -e "$runtime_dir" ]]; then
    if backup_daily_existing_runtime_valid "$runtime_dir" "$applied_sha"; then
      printf '%s\n' "$runtime_dir"
      return 0
    fi
    echo "Refusing to replace invalid immutable backup runtime: $runtime_dir" >&2
    return "$EXIT_APPLY_FAILED"
  fi

  install -d -m 0755 "$base"
  tmp="$base/.${applied_sha}.tmp.$$"
  rm -rf "$tmp"
  install -d -m 0755 "$tmp/bin" "$tmp/lib" "$tmp/runtime" || rc=$?
  if (( rc == 0 )); then install -m 0755 "$REPO_ROOT/scripts/backup/daily-user-backup.sh" "$tmp/bin/daily-user-backup" || rc=$?; fi
  if (( rc == 0 )); then install -m 0755 "$REPO_ROOT/scripts/backup/restic-retention.sh" "$tmp/bin/restic-retention" || rc=$?; fi
  if (( rc == 0 )); then install -m 0644 "$REPO_ROOT/lib/backup_runtime.sh" "$tmp/lib/backup_runtime.sh" || rc=$?; fi
  if (( rc == 0 )); then install -m 0644 "$REPO_ROOT/lib/backup_runtime_bundle.sh" "$tmp/lib/backup_runtime_bundle.sh" || rc=$?; fi
  if (( rc == 0 )); then backup_daily_write_config_snapshot "$tmp/runtime/backup-runtime.conf" || rc=$?; fi
  if (( rc == 0 )); then install -m 0644 /dev/null "$tmp/runtime/APPLIED_SHA" || rc=$?; fi
  if (( rc == 0 )); then printf '%s\n' "$applied_sha" > "$tmp/runtime/APPLIED_SHA" || rc=$?; fi
  if (( rc == 0 )); then
    (
      cd "$tmp"
      find bin lib runtime -type f -print0 | sort -z | xargs -0 sha256sum > MANIFEST.sha256
      sha256sum --check --status MANIFEST.sha256
    ) || rc=$?
  fi
  if (( rc != 0 )); then
    rm -rf "$tmp"
    return "$rc"
  fi

  # GNU mv -T treats the destination as a path, never as a directory target.
  # If a concurrent APPLY wins this race, mv fails and we validate that winner.
  if mv -T -- "$tmp" "$runtime_dir"; then
    :
  else
    rc=$?
    rm -rf "$tmp"
    backup_daily_existing_runtime_valid "$runtime_dir" "$applied_sha" || return "$rc"
  fi
  printf '%s\n' "$runtime_dir"
}

backup_daily_write_units() {
  local runtime_dir="$1" service retention_service retention_timer
  install -d -m 0755 "$HOME/.config/systemd/user"
  install -m 0644 "$REPO_ROOT/systemd/user/fedora-gnome-daily-backup.timer" "$HOME/.config/systemd/user/fedora-gnome-daily-backup.timer"

  service="$HOME/.config/systemd/user/fedora-gnome-daily-backup.service"
  cat > "$service" <<EOF
[Unit]
Description=Encrypted daily Fedora workstation user backup
After=network-online.target

[Service]
Type=oneshot
Environment="FEDORA_GNOME_CUSTOM_RUNTIME_ROOT=$runtime_dir"
ExecStart=$runtime_dir/bin/daily-user-backup
EOF
  chmod 0644 "$service"

  retention_service="$HOME/.config/systemd/user/fedora-gnome-restic-retention.service"
  cat > "$retention_service" <<EOF
[Unit]
Description=FEDORA_GNOME_CUSTOM periodic Restic retention
After=network-online.target

[Service]
Type=oneshot
Environment="FEDORA_GNOME_CUSTOM_RUNTIME_ROOT=$runtime_dir"
ExecStart=$runtime_dir/bin/restic-retention
EOF
  chmod 0644 "$retention_service"

  retention_timer="$HOME/.config/systemd/user/fedora-gnome-restic-retention.timer"
  cat > "$retention_timer" <<EOF
[Unit]
Description=Weekly FEDORA_GNOME_CUSTOM Restic retention

[Timer]
OnCalendar=${RESTIC_RETENTION_ON_CALENDAR:-Sun *-*-* 04:15:00}
Persistent=true
RandomizedDelaySec=${RESTIC_RETENTION_RANDOMIZED_DELAY_SEC:-1800}

[Install]
WantedBy=timers.target
EOF
  chmod 0644 "$retention_timer"
}

backup_daily_apply() {
  local applied_sha runtime_dir
  is_true "${DAILY_BACKUP_ENABLED:-true}" || return 0
  applied_sha="$(repo_commit)"
  [[ "$applied_sha" =~ ^[0-9a-fA-F]{40}$ ]] || return "$EXIT_APPLY_FAILED"

  if is_true "${DRY_RUN:-true}"; then
    log_info BACKUP "Would install autonomous backup runtime for SHA $applied_sha and daily/retention user timers"
    return 0
  fi

  runtime_dir="$(backup_daily_install_runtime "$applied_sha")" || return "$EXIT_APPLY_FAILED"
  backup_daily_write_units "$runtime_dir" || return "$EXIT_APPLY_FAILED"
  systemctl --user daemon-reload
  systemctl --user enable --now fedora-gnome-daily-backup.timer
  if is_true "${RESTIC_RETENTION_TIMER_ENABLED:-true}" && is_true "${BACKUP_PRUNE_AUTOMATICALLY:-true}"; then
    systemctl --user enable --now fedora-gnome-restic-retention.timer
  else
    systemctl --user disable --now fedora-gnome-restic-retention.timer >/dev/null 2>&1 || true
  fi
}

backup_daily_postcheck() {
  local applied_sha runtime_dir
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${DAILY_BACKUP_ENABLED:-true}" || return 0
  applied_sha="$(repo_commit)"
  runtime_dir="$(backup_daily_runtime_dir "$applied_sha")"
  backup_daily_existing_runtime_valid "$runtime_dir" "$applied_sha" || return "$EXIT_POSTCHECK_FAILED"
  grep -Fq "FEDORA_GNOME_CUSTOM_RUNTIME_ROOT=$runtime_dir" "$HOME/.config/systemd/user/fedora-gnome-daily-backup.service" || return "$EXIT_POSTCHECK_FAILED"
  systemctl --user is-enabled --quiet fedora-gnome-daily-backup.timer || return "$EXIT_POSTCHECK_FAILED"
  if is_true "${RESTIC_RETENTION_TIMER_ENABLED:-true}" && is_true "${BACKUP_PRUNE_AUTOMATICALLY:-true}"; then
    systemctl --user is-enabled --quiet fedora-gnome-restic-retention.timer || return "$EXIT_POSTCHECK_FAILED"
  fi
  "$REPO_ROOT/diagnostics/daily-backup-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
}

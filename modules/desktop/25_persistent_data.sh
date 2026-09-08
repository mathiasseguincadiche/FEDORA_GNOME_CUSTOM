#!/usr/bin/env bash
set -Eeuo pipefail

source "$REPO_ROOT/lib/persistent_data.sh"

desktop_persistent_data_precheck() {
  command_exists findmnt || return "$EXIT_PRECHECK_FAILED"
  if is_true "${DRY_RUN:-true}"; then
    return 0
  fi
  command_exists xdg-user-dirs-update || return "$EXIT_PRECHECK_FAILED"
  command_exists xdg-user-dir || return "$EXIT_PRECHECK_FAILED"
  persistent_data_validate_mount || {
    log_error DESKTOP '/data must be the dedicated EXT4 second T705 and distinct from root'
    return "$EXIT_PRECHECK_FAILED"
  }
  persistent_data_owner_user >/dev/null || return "$EXIT_PRECHECK_FAILED"
  command_exists semanage || return "$EXIT_PRECHECK_FAILED"
  command_exists restorecon || return "$EXIT_PRECHECK_FAILED"
}

desktop_persistent_data_plan() {
  cat <<'EOF'
PERSISTENT DATA LAYOUT ON SECOND T705:
- preserve /data as an operator-prepared EXT4 mount; never partition or format it
- create /data/Documents, /data/Projets, /data/ISO and /data/Jeux without deleting existing contents
- keep /data/libvirt reserved for KVM/libvirt
- make /data/Documents the XDG Documents directory
- apply persistent SELinux user_home_t labels to the four user-data roots
- daily/full Restic protects Documents and Projets; ISO and Jeux remain excluded by default
EOF
}

desktop_persistent_data_apply() {
  local user group path pattern fcontexts=''
  user="$(persistent_data_owner_user 2>/dev/null || true)"
  if [[ -z "$user" ]]; then
    is_true "${DRY_RUN:-true}" && user='operator'
  fi
  [[ -n "$user" ]] || return "$EXIT_APPLY_FAILED"
  if [[ "$user" == operator && "${DRY_RUN:-true}" == true ]]; then
    group='operator'
  else
    group="$(id -gn "$user")"
  fi

  if ! is_true "${DRY_RUN:-true}"; then
    fcontexts="$(sudo semanage fcontext -l 2>/dev/null | awk '{print $1}' || true)"
  fi

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    # Never remove or recursively rewrite the existing payload. Only converge
    # the directory root itself so a reused second T705 keeps its contents.
    run_mutating DESKTOP sudo install -d "$path" || return "$EXIT_APPLY_FAILED"
    run_mutating DESKTOP sudo chown "$user:$group" "$path" || return "$EXIT_APPLY_FAILED"
    run_mutating DESKTOP sudo chmod 0750 "$path" || return "$EXIT_APPLY_FAILED"

    pattern="${path}(/.*)?"
    if ! is_true "${DRY_RUN:-true}"; then
      if grep -Fxq "$pattern" <<<"$fcontexts"; then
        run_mutating DESKTOP sudo semanage fcontext -m -t user_home_t "$pattern" || return "$EXIT_APPLY_FAILED"
      else
        run_mutating DESKTOP sudo semanage fcontext -a -t user_home_t "$pattern" || return "$EXIT_APPLY_FAILED"
        fcontexts+=$'\n'"$pattern"
      fi
      run_mutating DESKTOP sudo restorecon -R "$path" || return "$EXIT_APPLY_FAILED"
    else
      run_mutating DESKTOP sudo semanage fcontext -a -t user_home_t "$pattern" || return "$EXIT_APPLY_FAILED"
      run_mutating DESKTOP sudo restorecon -R "$path" || return "$EXIT_APPLY_FAILED"
    fi
  done < <(persistent_data_layout_paths)

  if (( EUID == 0 )) && [[ "$user" != root ]]; then
    run_mutating DESKTOP sudo -H -u "$user" -- xdg-user-dirs-update --set DOCUMENTS "$(persistent_data_documents)" || return "$EXIT_APPLY_FAILED"
  else
    run_mutating DESKTOP xdg-user-dirs-update --set DOCUMENTS "$(persistent_data_documents)" || return "$EXIT_APPLY_FAILED"
  fi
}

desktop_persistent_data_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  "$REPO_ROOT/diagnostics/data-storage-doctor" --quiet || return "$EXIT_POSTCHECK_FAILED"
}

#!/usr/bin/env bash
# Disposable QEMU guest only; never runs install.sh --apply or signs a gate.
set -Eeuo pipefail
export LC_ALL=C
[[ "$EUID" == 0 && "$(hostname)" == fgc-fedora-ci && -e /etc/fgc-ci-lab ]] || { echo "Guest guard failed: euid=$EUID hostname=$(hostname) lab_marker=$(test -e /etc/fgc-ci-lab && echo present || echo missing)" >&2; exit 50; }
virt="$(systemd-detect-virt)"
case "$virt" in kvm|qemu) ;; *) echo "Guest virtualization guard failed: $virt" >&2; exit 50 ;; esac
REPO=/opt/fgc-lab/repo
LAB_USER=lab
LAB_HOME=/home/lab
LAB_UID="$(id -u "$LAB_USER")"
EXPECTED_COMMIT="${2:-}"
LAB_RELEASE="${3:-44}"
LAB_EXTENSION_MODE="${4:-curated}"
printf 'Guest profile release=%s extensions=%s action=%s\n' "$LAB_RELEASE" "$LAB_EXTENSION_MODE" "${1:-missing}"
case "$LAB_RELEASE:$LAB_EXTENSION_MODE" in 44:curated|45:native|45:curated) ;; *) echo 'Unsupported guest profile' >&2; exit 50;; esac
EXPECTED_GNOME_MAJOR="$((LAB_RELEASE+6))"
[[ "$EXPECTED_COMMIT" =~ ^[0-9a-f]{40}$ && "$(cat "$REPO/CI_COMMIT")" == "$EXPECTED_COMMIT" ]] || { echo "Guest commit guard failed: expected=$EXPECTED_COMMIT actual=$(cat "$REPO/CI_COMMIT")" >&2; exit 50; }
# shellcheck source=lib/backup_runtime.sh
source "$REPO/lib/backup_runtime.sh"
# shellcheck source=.github/scripts/fedora-greeter-ready.sh
source "$REPO/.github/scripts/fedora-greeter-ready.sh"
# shellcheck source=config/gnome-extensions.lock
if [[ "$LAB_RELEASE:$LAB_EXTENSION_MODE" == 45:curated ]]; then
  # Reviewed GNOME 51 candidate is read only for the isolated curated lab.
  # The native preview intentionally has no candidate dependency.
  source "$REPO/profiles/fedora45/gnome-extensions.lock"
else
  source "$REPO/config/gnome-extensions.lock"
fi
# shellcheck source=config/gnome.conf
source "$REPO/config/gnome.conf"

failure() {
  local rc=$?
  trap - ERR
  echo "Guest action ${1:-unknown} failed (exit=$rc); collecting diagnostics." >&2
  systemctl --failed --no-pager >&2 || true
  journalctl --no-pager -b -u systemd-binfmt.service -u systemd-modules-load.service -n 100 >&2 || true
  for key in enabled-extensions disabled-extensions disable-user-extensions; do
    printf 'GNOME setting %s: ' "$key" >&2
    as_user gsettings get org.gnome.shell "$key" >&2 || true
  done
  journalctl --no-pager -b _COMM=gnome-shell -n 100 >&2 || true
  journalctl --no-pager -b -1 -u "user@$LAB_UID.service" -n 200 >&2 || true
  journalctl --no-pager -b -u gdm -u "user@$LAB_UID.service" -n 120 >&2 || true
  for log in /tmp/fgc-critical.log /tmp/fgc-coredumps.log /tmp/fgc-failed-units.log /tmp/fgc-user-failed-units.log; do
    [[ ! -f "$log" ]] || cat "$log" >&2
  done
  exit "$rc"
}
journal_health() {
  local journal_boot="$1"
  if ! journalctl --quiet --no-pager -b "$journal_boot" -p emerg..crit > /tmp/fgc-critical.log; then
    echo "Unable to read critical journal for boot $journal_boot" >&2
    return 1
  fi
  if [[ -s /tmp/fgc-critical.log ]]; then
    echo "Critical journal entries for boot $journal_boot:" >&2
    cat /tmp/fgc-critical.log >&2
    return 1
  fi
  if ! journalctl --quiet --no-pager -b "$journal_boot" -t systemd-coredump -o json > /tmp/fgc-coredumps.log; then
    echo "Unable to read coredump journal for boot $journal_boot" >&2
    return 1
  fi
  if [[ -s /tmp/fgc-coredumps.log ]]; then
    echo "Coredumps recorded for boot $journal_boot:" >&2
    cat /tmp/fgc-coredumps.log >&2
    return 1
  fi
  systemctl --failed --no-legend --no-pager > /tmp/fgc-failed-units.log
  if [[ -s /tmp/fgc-failed-units.log ]]; then
    echo "Failed system units:" >&2
    cat /tmp/fgc-failed-units.log >&2
    return 1
  fi
}

ACTION="${1:-unknown}"
trap 'failure "$ACTION"' ERR

as_user() {
  sudo -u "$LAB_USER" env HOME="$LAB_HOME" XDG_RUNTIME_DIR="/run/user/$LAB_UID" \
    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$LAB_UID/bus" "$@"
}
require_session() {
  local sid
  systemctl is-active --quiet gdm
  gnome-shell --version | grep -Eq "^GNOME Shell $EXPECTED_GNOME_MAJOR([.]|$)"
  pgrep -u "$LAB_UID" -x gnome-shell >/dev/null
  sid="$(loginctl list-sessions --no-legend | awk -v u="$LAB_USER" '$3==u {print $1}')"
  local found=false candidate
  for candidate in $sid; do
    if [[ "$(loginctl show-session "$candidate" -p Type --value)" == wayland &&
          "$(loginctl show-session "$candidate" -p Active --value)" == yes ]]; then found=true; fi
  done
  $found
  as_user systemctl --user is-active --quiet graphical-session.target
  as_user gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell \
    --method org.freedesktop.DBus.Peer.Ping
}
extension_settings() {
  for key in enabled-extensions disabled-extensions disable-user-extensions; do
    printf '%s=' "$key"
    as_user gsettings get org.gnome.shell "$key"
  done
}
check_extension_settings() {
  extension_settings > /tmp/fgc-extension-settings.actual
  cmp /var/lib/fgc-lab/extension-settings.expected /tmp/fgc-extension-settings.actual
}

check_extensions() {
  check_extension_settings
  [[ "$LAB_EXTENSION_MODE" == curated ]] || { echo 'DEFERRED: six curated extensions; Fedora 45 native GNOME preview only'; return 0; }
  local uuid output
  for uuid in "$DASH_TO_DOCK_UUID" "$APPINDICATOR_UUID" "$DING_UUID" "$SHOW_DESKTOP_PLUS_UUID" "$RESOURCE_MONITOR_UUID" "$TILING_ASSISTANT_UUID"; do
    # Shell activation is asynchronous. Observe it; never repair a reboot here.
    for _ in {1..60}; do
      output="$(as_user gnome-extensions info "$uuid")"
      if grep -Eq 'State:[[:space:]]+ERROR([[:space:]]|$)' <<<"$output"; then break; fi
      if grep -Eq 'Enabled:[[:space:]]+Yes([[:space:]]|$)' <<<"$output" &&
         grep -Eq 'State:[[:space:]]+ACTIVE([[:space:]]|$)' <<<"$output"; then break; fi
      sleep 1
    done
    printf '%s\n' "$output"
    grep -Eq 'Enabled:[[:space:]]+Yes([[:space:]]|$)' <<<"$output"
    grep -Eq 'State:[[:space:]]+ACTIVE([[:space:]]|$)' <<<"$output"
  done
  if [[ "$LAB_RELEASE" == 45 ]]; then
    require_session
    as_user python3 "$REPO/.github/scripts/fedora45-ci-extension-audit.py" \
      | tee /var/lib/fgc-lab/gnome51-curated-runtime.json
  fi
}
settle_session() {
  require_session
  check_extensions
  # GNOME clears its startup protection marker itself after 60 seconds.
  # Never delete the marker or turn protection off to force a PASS.
  for _ in {1..90}; do
    [[ -e "/run/user/$LAB_UID/gnome-shell-disable-extensions" ]] || break
    sleep 1
  done
  [[ ! -e "/run/user/$LAB_UID/gnome-shell-disable-extensions" ]]
  require_session
  check_extensions

}
check_tpm() {
  tpm2_nvread 0x1500016 -C o -s 32 -o /tmp/fgc-tpm-read
  cmp /var/lib/fgc-lab/tpm-canary /tmp/fgc-tpm-read
}
check_data() {
  cmp /var/lib/fgc-lab/data-canary "$LAB_HOME/.config/fgc-lab/settings with spaces"
  [[ "$(stat -c %a "$LAB_HOME/.config/fgc-lab/settings with spaces")" == 600 ]]
  [[ "$(readlink "$LAB_HOME/.config/fgc-lab/link")" == 'settings with spaces' ]]
  cmp /var/lib/fgc-lab/data-canary "$LAB_HOME/Documents/Lab/document.txt"
}
case "${1:-}" in
  ready)
    require_session
    ;;
  prepare-base)
    [[ "$LAB_RELEASE" == 45 ]]
    grep -Eq '^VERSION_ID="?45"?$' /etc/os-release
    [[ "$(getenforce)" == Enforcing ]]
    # A Beta seed can predate its current GNOME/systemd/kernel packages.
    # Upgrade the official base and boot that transaction before installing
    # a desktop that may require newly installed kernel modules and schemas.
    dnf -y upgrade --refresh
    mkdir -p /var/lib/fgc-lab
    rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core |
      sort -V | tail -n1 > /var/lib/fgc-lab/maintenance-kernel
    [[ -s /var/lib/fgc-lab/maintenance-kernel ]]
    ;;
  install)
    if [[ "$LAB_RELEASE" == 45 ]]; then
      [[ "$(uname -r)" == "$(cat /var/lib/fgc-lab/maintenance-kernel)" ]]
      printf 'PASS: updated Fedora base booted kernel=%s\n' "$(uname -r)"
    fi
    grep -Eq "^VERSION_ID=\"?$LAB_RELEASE\"?$" /etc/os-release
    [[ "$(getenforce)" == Enforcing ]]
    mkdir -p /etc/systemd/journald.conf.d /var/log/journal
    printf '[Journal]\nStorage=persistent\nSystemMaxUse=128M\n' > /etc/systemd/journald.conf.d/90-fgc-lab.conf
    systemd-tmpfiles --create --prefix /var/log/journal
    systemctl restart systemd-journald
    journalctl --flush
    if [[ "$LAB_EXTENSION_MODE" == curated ]]; then
    for prefix in DING SHOW_DESKTOP_PLUS RESOURCE_MONITOR TILING_ASSISTANT; do
      as_user test -r "/opt/fgc-lab/extensions/$prefix.zip"
    done
    fi
    dnf -y install @gnome-desktop ptyxis nautilus gvfs sushi file-roller \
      xdg-desktop-portal-gnome mesa-dri-drivers borgbackup jq git unzip \
      tpm2-tools firewalld python3 curl gjs gnome-shell-extension-dash-to-dock \
      gnome-shell-extension-appindicator gnome-text-editor libreoffice poppler-utils gnome-software dconf
    if [[ "$LAB_RELEASE" == 45 ]]; then
      rpm -q gsettings-desktop-schemas gnome-shell mutter
      gsettings list-keys org.gnome.desktop.peripherals.mouse | grep -Fxq custom-accel-config
    fi
    # Exercise the production lifecycle writer in this disposable Fedora only.
    (
      # shellcheck source=modules/desktop/27_lifecycle.sh
      source "$REPO/modules/desktop/27_lifecycle.sh"
      run_mutating(){ shift; "$@"; }
      is_true(){ [[ "$1" == true ]]; }
      desktop_lifecycle_apply
    )
    passwd -d "$LAB_USER"
    systemctl enable --now firewalld
    mkdir -p /var/lib/fgc-lab
    # Automatic login is confined to this throwaway CI image.
    cat > /etc/gdm/custom.conf <<'CONF'
[daemon]
AutomaticLoginEnable=True
AutomaticLogin=lab
WaylandEnable=true
CONF
    mkdir -p "$LAB_HOME/.config" /var/lib/AccountsService/users
    cat > /var/lib/AccountsService/users/lab <<'CONF'
[User]
Session=gnome
SystemAccount=false
CONF
    touch "$LAB_HOME/.config/gnome-initial-setup-done"
    # GNOME Shell may need more than its default five-second systemd stop
    # grace period when the disposable QEMU lab uses software rendering.
    # This override is guest-local only. Any timeout, ABRT or core dump still
    # fails journal_health; no failures are hidden or systemd states reset.
    mkdir -p "$LAB_HOME/.config/systemd/user/org.gnome.Shell@user.service.d"
    printf '[Service]\nTimeoutStopSec=30s\n' \
      > "$LAB_HOME/.config/systemd/user/org.gnome.Shell@user.service.d/90-fgc-lab-shutdown.conf"
    chown -R "$LAB_USER:$LAB_USER" "$LAB_HOME/.config"
    # Use the reviewed production artifact installer, without loosening gates.
    if [[ "$LAB_EXTENSION_MODE" == curated ]]; then
    for prefix in DING SHOW_DESKTOP_PLUS RESOURCE_MONITOR TILING_ASSISTANT; do
      if [[ "$LAB_RELEASE" == 45 ]]; then
        as_user bash "$REPO/.github/scripts/fedora45-ci-install-extension.sh" "$prefix"
      else
        as_user env FGC_EXTENSION_ARTIFACT_CACHE=/opt/fgc-lab/extensions \
          bash "$REPO/scripts/gnome/install-pinned-extension.sh" "$prefix"
      fi
    done
    fi
    # Use the persistent user bus: multiple private dconf daemons can race.
    as_user systemctl --user daemon-reload
    as_user gsettings set org.gnome.desktop.session idle-delay 0
    as_user gsettings set org.gnome.desktop.screensaver lock-enabled false
    as_user gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type "'nothing'"
    # Persist the selected extensions before the first GDM session.
    # Reboot/recovery checks only observe these settings and active states.
    if [[ "$LAB_EXTENSION_MODE" == curated ]]; then
    as_user gsettings set org.gnome.shell enabled-extensions \
      "['$DASH_TO_DOCK_UUID', '$APPINDICATOR_UUID', '$DING_UUID', '$SHOW_DESKTOP_PLUS_UUID', '$RESOURCE_MONITOR_UUID', '$TILING_ASSISTANT_UUID']"
    else as_user gsettings set org.gnome.shell enabled-extensions '[]'; fi
    as_user gsettings set org.gnome.shell disable-user-extensions false
    extension_settings > /var/lib/fgc-lab/extension-settings.expected
    dnf clean all
    systemctl set-default graphical.target
    systemctl start gdm
    ;;
  settled)
    settle_session
    ;;
  end-session)
    settle_session
    # The lab opens Nautilus and Ptyxis as dedicated transient user units.
    # Stop these test clients before ending GNOME: tearing down their Wayland
    # windows concurrently with Shell/Xwayland shutdown can stall Mutter's X11
    # roundtrip and produce a real gnome-shell coredump in a software-rendered VM.
    # This does not disable extensions, reset units or ignore any crash.
    for unit in fgc-lab-ptyxis.service fgc-lab-nautilus.service; do
      unit_state="$(as_user systemctl --user show --property=ActiveState --value "$unit")"
      case "$unit_state" in
        active|activating|deactivating|reloading)
          as_user systemctl --user stop "$unit"
          ;;
        inactive) ;;
        *)
          echo "Refusing GNOME logout: $unit is $unit_state" >&2
          exit 1
          ;;
      esac
      unit_state="$(as_user systemctl --user show --property=ActiveState --value "$unit")"
      if [[ "$unit_state" != inactive ]]; then
        echo "CI desktop client did not stop cleanly: $unit ($unit_state)" >&2
        exit 1
      fi
    done
    # The unit stop returns before Mutter/Xwayland has necessarily drained
    # queued window teardown events in a software-rendered guest.
    sleep 3
    # Confirm the compositor still answers after its test clients have left.
    require_session
    # Close GNOME through its supported logout API before stopping system buses.
    as_user gnome-session-quit --logout --no-prompt
    for _ in {1..90}; do
      pgrep -u "$LAB_UID" -x gnome-shell >/dev/null || break
      sleep 1
    done
    if pgrep -u "$LAB_UID" -x gnome-shell >/dev/null; then
      echo "GNOME did not log out cleanly." >&2; exit 1
    fi
    # Wait for the newly created greeter scope/bus before stopping GDM.
    # Never reset failed units or ignore shutdown journals to force success.
    fedora_lab_wait_greeter
    systemctl stop gdm
    journalctl --sync
    # Check logout errors now, including the last VM shutdown with no next boot.
    journal_health 0
    ;;
  session)
    require_session
    check_extensions
    for key in download-updates allow-updates; do
      [[ "$(as_user gsettings get org.gnome.software "$key")" == false ]]
      [[ "$(as_user gsettings writable org.gnome.software "$key")" == false ]]
    done
    as_user systemd-run --user --collect --unit=fgc-lab-nautilus \
      nautilus --new-window "$LAB_HOME"
    as_user systemd-run --user --collect --unit=fgc-lab-ptyxis \
      ptyxis --standalone --new-window --working-directory="$LAB_HOME" -- \
      bash -c 'printf terminal-ready; sleep 300'
    sleep 10
    pgrep -u "$LAB_UID" -x nautilus >/dev/null
    pgrep -u "$LAB_UID" -x ptyxis >/dev/null
    as_user systemctl --user is-active --quiet xdg-desktop-portal.service
    as_user bash "$REPO/.github/scripts/desktop-document-smoke.sh"
    ;;
  seed)
    mkdir -p "$LAB_HOME/.config/fgc-lab" "$LAB_HOME/Documents/Lab" /var/lib/fgc-lab
    printf 'Fedora GNOME recovery %s\n' "$EXPECTED_COMMIT" > /var/lib/fgc-lab/data-canary
    cp /var/lib/fgc-lab/data-canary "$LAB_HOME/.config/fgc-lab/settings with spaces"
    cp /var/lib/fgc-lab/data-canary "$LAB_HOME/Documents/Lab/document.txt"
    chmod 0600 "$LAB_HOME/.config/fgc-lab/settings with spaces"
    ln -s 'settings with spaces' "$LAB_HOME/.config/fgc-lab/link"
    chown -R "$LAB_USER:$LAB_USER" "$LAB_HOME/.config/fgc-lab" "$LAB_HOME/Documents"
    printf '%.32s' "$EXPECTED_COMMIT" > /var/lib/fgc-lab/tpm-canary
    tpm2_nvdefine 0x1500016 -C o -s 32 -a 'ownerread|ownerwrite'
    tpm2_nvwrite 0x1500016 -C o -i /var/lib/fgc-lab/tpm-canary
    check_tpm
    backup_engine_require
    backup_engine_env /var/lib/fgc-lab/files-repository
    backup_engine_init
    identity="$(backup_engine_create daily -- "$LAB_HOME/.config/fgc-lab" "$LAB_HOME/Documents/Lab")"
    printf '%s\n' "$identity" > /var/lib/fgc-lab/files-archive.txt
    read -r archive aid <<<"$identity"
    backup_engine_archive_matches "$archive" "$aid" daily
    backup_engine_check daily "$archive"
    check_data
    # Existing integration test exercises the actual installed daily runtime,
    # staging-only restore, permissions, symlinks and encryption rejection.
    bash "$REPO/tests/test_borg_roundtrip.sh"
    tar -C /var/lib/fgc-lab -czf /tmp/fgc-files-recovery.tar.gz \
      files-repository files-archive.txt data-canary
    chown "$LAB_USER:$LAB_USER" /tmp/fgc-files-recovery.tar.gz
    ;;
  recovered|persistent)
    require_session
    check_extensions
    check_tpm
    check_data
    [[ "$(getenforce)" == Enforcing ]]
    systemctl is-active --quiet firewalld
    # Fail if any outbound connection escapes the restored VM network.
    if [[ "$1" == recovered ]]; then
    python3 - <<'PY'
import socket
for host in ("1.1.1.1", "10.0.2.2"):
    try:
        with socket.create_connection((host, 443), timeout=3):
            raise SystemExit("recovery network is not isolated")
    except OSError:
        pass
PY
    fi
    ;;
  rebuild)
    # Fresh Fedora OS: application packages were installed independently.
    # Only explicit test files are copied out of a verified empty staging.
    require_session
    if [[ -e "$LAB_HOME/.config/fgc-lab" || -e "$LAB_HOME/Documents/Lab" ]]; then
      echo 'Rebuild invariant violated: restored user data already exists before recovery' >&2
      ls -ld "$LAB_HOME/.config/fgc-lab" "$LAB_HOME/Documents/Lab" >&2 || true
      exit 1
    fi
    echo 'Rebuild: fresh user-data absence verified'
    echo "Rebuild: validating transferred recovery bundle"
    tar -tzf /tmp/fgc-files-recovery.tar.gz >/dev/null
    tar -C /var/lib/fgc-lab -xzf /tmp/fgc-files-recovery.tar.gz
    echo "Rebuild: recovery bundle extracted"
    backup_engine_env /var/lib/fgc-lab/files-repository
    backup_engine_repo_ready
    read -r archive aid < /var/lib/fgc-lab/files-archive.txt
    backup_engine_archive_matches "$archive" "$aid" daily
    backup_engine_check daily "$archive"
    staging="$LAB_HOME/Restores/fedora-gnome-custom/rebuilt"
    HOME="$LAB_HOME" backup_runtime_restore_target_valid "$staging"
    [[ ! -e "$staging" ]]
    mkdir -p "$staging"
    backup_engine_extract "$archive" "$staging"
    cmp /var/lib/fgc-lab/data-canary "$staging$LAB_HOME/.config/fgc-lab/settings with spaces"
    [[ "$(stat -c %a "$staging$LAB_HOME/.config/fgc-lab/settings with spaces")" == 600 ]]
    [[ "$(readlink "$staging$LAB_HOME/.config/fgc-lab/link")" == 'settings with spaces' ]]
    cp -a "$staging$LAB_HOME/.config/fgc-lab" "$LAB_HOME/.config/"
    mkdir -p "$LAB_HOME/Documents"
    cp -a "$staging$LAB_HOME/Documents/Lab" "$LAB_HOME/Documents/"
    restorecon -RF "$LAB_HOME/.config/fgc-lab" "$LAB_HOME/Documents/Lab"
    check_data
    [[ "$(getenforce)" == Enforcing ]]
    ;;
  rebuilt-check)
    require_session
    check_extensions
    check_data
    [[ "$(getenforce)" == Enforcing ]]
    systemctl is-active --quiet firewalld
    ;;
  collect)
    # Keep complete reads and preserve stderr; no piped grep hides read errors.
    mkdir -p /tmp/fgc-evidence
    journalctl --no-pager -b > /tmp/fgc-evidence/boot-journal.log 2> /tmp/fgc-evidence/journal-read.err
    journalctl --no-pager -k -b > /tmp/fgc-evidence/kernel-journal.log
    journalctl --no-pager > /tmp/fgc-evidence/all-boots-journal.log
    journalctl --no-pager -b _UID="$LAB_UID" > /tmp/fgc-evidence/user-journal.log
    systemctl --failed --no-pager > /tmp/fgc-evidence/failed-units.txt
    as_user systemctl --user --failed --no-pager > /tmp/fgc-evidence/user-failed-units.txt
    rpm -qa | sort > /tmp/fgc-evidence/packages.txt
    loginctl list-sessions > /tmp/fgc-evidence/sessions.txt
    lsblk -f > /tmp/fgc-evidence/lsblk.txt
    if [[ "$LAB_RELEASE:$LAB_EXTENSION_MODE" == 45:curated ]]; then
      [[ -s /var/lib/fgc-lab/gnome51-curated-runtime.json ]] || exit 1
      cp /var/lib/fgc-lab/gnome51-curated-runtime.json /tmp/fgc-evidence/gnome51-curated-runtime.json
    fi
    # Never open a lab-user-owned archive for writing as root in sticky /tmp:
    # Linux fs.protected_regular may correctly deny that. Build the evidence
    # in the root-owned lab state directory, then atomically replace the file
    # served over SCP after the tar operation has completely succeeded.
    evidence_tmp="$(mktemp /var/lib/fgc-lab/.evidence.XXXXXXXX.tar.gz)"
    if ! tar -C /tmp/fgc-evidence -czf "$evidence_tmp" .; then
      rm -f -- "$evidence_tmp"
      echo 'Cannot package guest evidence; refusing success' >&2
      exit 1
    fi
    chown "$LAB_USER:$LAB_USER" "$evidence_tmp"
    chmod 0600 "$evidence_tmp"
    mv -f -- "$evidence_tmp" /tmp/fgc-evidence.tar.gz
    as_user test -r /tmp/fgc-evidence.tar.gz
    ;;
  health|previous-health)
    journal_boot=0
    [[ "$ACTION" != previous-health ]] || journal_boot=-1
    # Actual crashes / kernel errors are fatal. Other messages remain evidence.
    journal_health "$journal_boot"
    as_user systemctl --user --failed --no-legend --no-pager > /tmp/fgc-user-failed-units.log
    [[ ! -s /tmp/fgc-user-failed-units.log ]]
    ;;
  *) exit 2 ;;
esac

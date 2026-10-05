#!/usr/bin/env bash
# Optional community display only; never changes fan or pump control.
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/lib/bootstrap.sh"; engine_bootstrap
# shellcheck source=hardware/deepcool-ld240.lock
source "$REPO_ROOT/hardware/deepcool-ld240.lock"
case "${1:-status}" in
  status)
    systemctl --user status fgc-ld240-display.service --no-pager
    ;;
  install)
    runtime_is_baremetal && hardware_platform_validate_dmi || exit "$EXIT_SECURITY_BLOCK"
    [[ "$EUID" != 0 && "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] || exit "$EXIT_PRECHECK_FAILED"
    lsusb -d "$DEEPCOOL_USB_VENDOR:$DEEPCOOL_USB_PRODUCT" | grep -q . || {
      ui_error 'Expected LD-series USB 3633:000a is not visible'; exit "$EXIT_PRECHECK_FAILED";
    }
    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
    curl --fail --location --proto '=https' --proto-redir '=https' --retry 3 "$DEEPCOOL_URL" -o "$tmp/display"
    printf '%s  %s\n' "$DEEPCOOL_SHA256" "$tmp/display" | sha256sum --check
    # No wildcard vendor permission and no world-writable device.
    printf 'SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3633", ATTRS{idProduct}=="000a", TAG+="uaccess", MODE="0600"\n' > "$tmp/70-fgc-ld240.rules"
    sudo install -d -m 0755 /usr/local/libexec/fgc
    sudo install -m 0755 "$tmp/display" /usr/local/libexec/fgc/deepcool-digital-linux
    sudo restorecon /usr/local/libexec/fgc/deepcool-digital-linux
    sudo install -m 0644 "$tmp/70-fgc-ld240.rules" /etc/udev/rules.d/70-fgc-ld240.rules
    sudo udevadm control --reload-rules
    # Replug the device or restart the session; do not grant permissions to other HIDs.
    mkdir -p "$HOME/.config/systemd/user"
    install -m 0644 "$REPO_ROOT/systemd/user/fgc-ld240-display.service" "$HOME/.config/systemd/user/"
    systemctl --user daemon-reload
    systemctl --user enable fgc-ld240-display.service
    ui_check INFO LD240 'Installed, not started: reconnect USB, then start the user service and visually verify the display.'
    ;;
  start)
    runtime_is_baremetal || exit "$EXIT_SECURITY_BLOCK"
    printf '%s  %s\n' "$DEEPCOOL_SHA256" /usr/local/libexec/fgc/deepcool-digital-linux | sha256sum --check
    systemctl --user start fgc-ld240-display.service
    systemctl --user is-active --quiet fgc-ld240-display.service
    ;;
  remove)
    if systemctl --user list-unit-files fgc-ld240-display.service --no-legend | grep -q fgc-ld240; then
      systemctl --user disable --now fgc-ld240-display.service
    fi
    rm -f "$HOME/.config/systemd/user/fgc-ld240-display.service"
    systemctl --user daemon-reload
    sudo rm -f /etc/udev/rules.d/70-fgc-ld240.rules /usr/local/libexec/fgc/deepcool-digital-linux
    sudo udevadm control --reload-rules
    ;;
  *) echo 'Usage: ld240-display.sh status|install|start|remove' >&2; exit "$EXIT_USAGE";;
esac

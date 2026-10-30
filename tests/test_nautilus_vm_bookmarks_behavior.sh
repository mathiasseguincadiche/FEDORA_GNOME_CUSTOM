#!/usr/bin/env bash
# The Nautilus VM access helper run for real with a fake virsh: it adds, replaces
# and removes only its own "Rocky DevOps" bookmark and never a user bookmark
# that merely contains that text.
# shellcheck disable=SC2016,SC2015
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "nautilus VM bookmarks behavior: FAIL: $*" >&2; exit 1; }
[[ "$EUID" != 0 ]] || { echo 'nautilus VM bookmarks behavior: SKIP (the helper refuses root by design)'; exit 0; }
mkdir -p "$tmp/bin" "$tmp/config/gtk-3.0"
printf '#!/usr/bin/env bash\n[[ "$1" == --connect ]] && shift 2\ncase "$1" in list) exit 0 ;; domifaddr) printf " vnet0  52:54:00:00:00:01  ipv4  %%s/24\n" "${T_IP:-192.168.50.101}" ;; *) exit 1 ;; esac\n' > "$tmp/bin/virsh"
chmod +x "$tmp/bin/virsh"
export PATH="$tmp/bin:$PATH" XDG_CONFIG_HOME="$tmp/config"
bookmarks="$tmp/config/gtk-3.0/bookmarks"
cat > "$bookmarks" <<'TXT'
file:///home/user/Documents Documents
file:///home/user/Notes%20Rocky%20DevOps Notes Rocky DevOps 2026
sftp://old@192.168.50.9/home/old Rocky DevOps
file:///home/user/Rocky%20DevOps
TXT
helper() { bash "$ROOT/scripts/kvm/configure_nautilus_vm_access.sh" "$@" > "$tmp/out" 2>&1; }
helper install || { cat "$tmp/out" >&2; fail 'install refused'; }
[[ "$(paste -sd'|' "$bookmarks")" == 'file:///home/user/Documents Documents|file:///home/user/Notes%20Rocky%20DevOps Notes Rocky DevOps 2026|file:///home/user/Rocky%20DevOps|sftp://mathias@192.168.50.101/home/mathias Rocky DevOps' ]] \
  || fail "unexpected bookmarks after install: $(paste -sd'|' "$bookmarks")"
[[ "$(stat -c %a "$bookmarks")" == 600 ]] || fail 'bookmarks readable by others'
T_IP=192.168.50.102 helper refresh
[[ "$(grep -c ' Rocky DevOps$' "$bookmarks")" == 1 ]] && grep -Fxq 'sftp://mathias@192.168.50.102/home/mathias Rocky DevOps' "$bookmarks" || fail 'refresh did not replace the managed bookmark'
helper show && [[ "$(<"$tmp/out")" == 'sftp://mathias@192.168.50.102/home/mathias Rocky DevOps' ]] || fail "show listed other bookmarks: $(<"$tmp/out")"
helper remove
[[ "$(paste -sd'|' "$bookmarks")" == 'file:///home/user/Documents Documents|file:///home/user/Notes%20Rocky%20DevOps Notes Rocky DevOps 2026|file:///home/user/Rocky%20DevOps' ]] \
  || fail "remove touched user bookmarks: $(paste -sd'|' "$bookmarks")"
echo 'nautilus VM bookmarks behavior: PASS'

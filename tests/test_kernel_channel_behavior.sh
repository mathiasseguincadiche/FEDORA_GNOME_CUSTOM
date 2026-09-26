#!/usr/bin/env bash
# Behavioral test: executes the kernel channel helpers against fake dnf5/rpm
# binaries instead of grepping source text (ADR 0012).
# shellcheck disable=SC2317,SC2034
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rc=$?; ((rc == 0)) || cat "$tmp/errors.log" 2>/dev/null >&2; rm -rf "$tmp"' EXIT
fail() { echo "kernel channel behavior: FAIL: $*" >&2; exit 1; }

mkdir -p "$tmp/bin"
cat > "$tmp/bin/dnf5" <<'SH'
#!/usr/bin/env bash
args="$*"
if [[ "$args" == *'repo list'* ]]; then
  printf 'repo id                                                    repo name\n'
  printf 'fedora                                                     Fedora 44\n'
  printf 'copr:copr.fedorainfracloud.org:group_kernel-vanilla:stable Kernel Vanilla\n'
  printf 'copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos CachyOS kernel\n'
  printf 'copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos-addons addons\n'
  printf 'copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos-lto LTO\n'
  exit 0
fi
if [[ "$args" == *repoquery* ]]; then
  pkg="${!#}"
  if [[ "$args" == *'--latest-limit'* ]]; then
    [[ "$pkg" == kernel-cachyos-core ]] && printf '7.2.8-cachyos1.fc44.x86_64\n'
    exit 0
  fi
  case "$pkg" in
    kernel-cachyos|kernel-cachyos-core|kernel-cachyos-modules|kernel-cachyos-devel-matched)
      printf '%s-7.2.8-cachyos1.fc44.x86_64\n' "$pkg" ;;
  esac
  exit 0
fi
exit 0
SH
cat > "$tmp/bin/rpm" <<'SH'
#!/usr/bin/env bash
pkg="${!#}"
case "$pkg" in
  kernel-core) printf '7.2.2-200.vanilla.fc44.x86_64\n7.2.5-200.vanilla.fc44.x86_64\n' ;;
  kernel-cachyos-core)
    if [[ -n "${FAKE_CACHYOS_INSTALLED:-}" ]]; then printf '%s\n' $FAKE_CACHYOS_INSTALLED; else printf 'package kernel-cachyos-core is not installed\n'; exit 1; fi ;;
esac
SH
cat > "$tmp/ldso-v3" <<'SH'
#!/usr/bin/env bash
printf 'Subdirectories of glibc-hwcaps directories, in priority order:\n  x86-64-v4\n  x86-64-v3 (supported, searched)\n  x86-64-v2 (supported, searched)\n'
SH
cat > "$tmp/ldso-v2" <<'SH'
#!/usr/bin/env bash
printf 'Subdirectories of glibc-hwcaps directories, in priority order:\n  x86-64-v3\n  x86-64-v2 (supported, searched)\n'
SH
chmod +x "$tmp/bin/"* "$tmp/ldso-v3" "$tmp/ldso-v2"

(
  PATH="$tmp/bin:$PATH"
  is_true() { [[ "${1,,}" == true ]]; }
  command_exists() { command -v "$1" >/dev/null 2>&1; }
  ui_error() { printf '%s\n' "$*" >> "$tmp/errors.log"; }
  source "$ROOT/lib/constants.sh"
  source "$ROOT/lib/kernel_lifecycle.sh"

  unset KERNEL_CHANNEL
  [[ "$(kernel_channel)" == vanilla ]] || fail 'default channel must stay vanilla when unset'
  KERNEL_CHANNEL=bogus
  if kernel_channel >/dev/null; then fail 'unknown channel accepted'; fi

  KERNEL_CHANNEL=vanilla
  [[ "$(kernel_lifecycle_channel_repo_id)" == 'copr:copr.fedorainfracloud.org:group_kernel-vanilla:stable' ]] || fail 'vanilla repo resolution'
  [[ "$(kernel_lifecycle_expected_nevra_count)" == 5 ]] || fail 'vanilla package set size'
  [[ "$(kernel_lifecycle_latest_installed)" == '7.2.5-200.vanilla.fc44.x86_64' ]] || fail 'vanilla latest installed'

  KERNEL_CHANNEL=cachyos
  [[ "$(kernel_lifecycle_channel_repo_id)" == 'copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos' ]] \
    || fail 'cachyos repo must match exactly one repo and ignore -addons/-lto'
  [[ "$(kernel_channel_core_package)" == kernel-cachyos-core ]] || fail 'cachyos core package'
  kernel_channel_release_matches '7.2.8-cachyos1.fc44.x86_64' || fail 'cachyos release marker'
  if kernel_channel_release_matches '7.2.5-200.vanilla.fc44.x86_64'; then fail 'vanilla release accepted as cachyos'; fi
  [[ "$(kernel_lifecycle_latest_available)" == '7.2.8-cachyos1.fc44.x86_64' ]] || fail 'cachyos latest available'

  mapfile -t nevras < <(kernel_lifecycle_latest_nevras '7.2.8-cachyos1.fc44.x86_64')
  [[ "${#nevras[@]}" -eq 3 ]] || fail "cachyos NEVRA set size ${#nevras[@]} (devel must stay optional)"
  KERNEL_CACHYOS_INSTALL_DEVEL=true
  mapfile -t nevras < <(kernel_lifecycle_latest_nevras '7.2.8-cachyos1.fc44.x86_64')
  [[ "${#nevras[@]}" -eq 4 && "${nevras[3]}" == kernel-cachyos-devel-matched-* ]] || fail 'devel-matched opt-in'
  KERNEL_CACHYOS_INSTALL_DEVEL=false

  # Nothing installed yet: must return an empty list, not fail under set -e.
  unset FAKE_CACHYOS_INSTALLED
  [[ -z "$(kernel_lifecycle_installed_releases)" ]] || fail 'not-installed message leaked into release list'
  [[ "$(kernel_lifecycle_installed_count)" == 0 ]] || fail 'installed count without cachyos'
  FAKE_CACHYOS_INSTALLED='7.2.8-cachyos1.fc44.x86_64 7.2.6-cachyos1.fc44.x86_64'
  export FAKE_CACHYOS_INSTALLED
  [[ "$(kernel_lifecycle_latest_installed)" == '7.2.8-cachyos1.fc44.x86_64' ]] || fail 'cachyos N'
  [[ "$(kernel_lifecycle_previous_installed)" == '7.2.6-cachyos1.fc44.x86_64' ]] || fail 'cachyos N-1'

  KERNEL_LDSO_PATH="$tmp/ldso-v3"
  kernel_lifecycle_cpu_supports_x86_64_v3 || fail 'x86-64-v3 not detected'
  KERNEL_CACHYOS_SELINUX_MODULE_LOAD=true
  kernel_channel_require_platform || fail 'valid cachyos platform rejected'
  KERNEL_CACHYOS_SELINUX_MODULE_LOAD=false
  rc=0; kernel_channel_require_platform || rc=$?
  [[ "$rc" -eq "$EXIT_CONFIG_FAILED" ]] || fail "SELinux trade-off must be explicit (rc=$rc)"
  KERNEL_CACHYOS_SELINUX_MODULE_LOAD=true
  KERNEL_LDSO_PATH="$tmp/ldso-v2"
  rc=0; kernel_channel_require_platform || rc=$?
  [[ "$rc" -eq "$EXIT_SECURITY_BLOCK" ]] || fail "x86-64-v2 CPU must be blocked (rc=$rc)"
  KERNEL_CHANNEL=vanilla
  kernel_channel_require_platform || fail 'vanilla must not require x86-64-v3'
)
echo 'kernel channel behavior: PASS'

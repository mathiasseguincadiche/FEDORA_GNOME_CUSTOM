#!/usr/bin/env bash
# Real helper execution: reject obsolete/custom channels, stale RPMs and RCs.
# shellcheck disable=SC2317,SC2034
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"
cat > "$tmp/bin/dnf5" <<'SH'
#!/usr/bin/env bash
if [[ "$*" == *'repo list'* ]]; then
  printf 'repo id repo name\nfedora Fedora\ncopr:copr.fedorainfracloud.org:group_kernel-vanilla:stable Stable\ncopr:copr.fedorainfracloud.org:group_kernel-vanilla:stable-rc RC\n'
elif [[ "$*" == *repoquery* ]]; then
  printf '%s\n' "${FAKE_CANDIDATE:-7.2.9-200.vanilla.fc44.x86_64}"
fi
SH
cat > "$tmp/bin/rpm" <<'SH'
#!/usr/bin/env bash
printf '7.2.8-200.vanilla.fc44.x86_64\n7.2.9-200.vanilla.fc44.x86_64\n'
SH
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
source "$ROOT/lib/constants.sh"
REPO_ROOT="$ROOT"
source "$ROOT/lib/kernel_lifecycle.sh"
command_exists() { command -v "$1" >/dev/null; }
ui_error() { printf '%s\n' "$*" >&2; }
unset KERNEL_CHANNEL
[[ "$(kernel_channel)" == vanilla ]]
for KERNEL_CHANNEL in cachyos mainline stable-rc custom; do
  if kernel_channel >/dev/null; then exit 1; fi
done
KERNEL_CHANNEL=vanilla
KERNEL_VANILLA_COPR=@kernel-vanilla/stable
kernel_channel_require_platform
[[ "$(kernel_lifecycle_channel_repo_id)" == copr:copr.fedorainfracloud.org:group_kernel-vanilla:stable ]]
[[ "$(kernel_lifecycle_expected_nevra_count)" == 5 ]]
[[ "$(kernel_lifecycle_latest_installed)" == 7.2.9-200.vanilla.fc44.x86_64 ]]
[[ "$(kernel_lifecycle_previous_installed)" == 7.2.8-200.vanilla.fc44.x86_64 ]]
kernel_lifecycle_upstream_latest() { printf '7.2.9\n'; }
[[ "$(kernel_lifecycle_resolve_latest_stable)" == 7.2.9-200.vanilla.fc44.x86_64 ]]
KERNEL_MIN_VERSION=7.2.2
export FAKE_CANDIDATE=7.2.8-200.vanilla.fc44.x86_64
if kernel_lifecycle_resolve_latest_stable; then exit 1; fi
export FAKE_CANDIDATE=7.3.0-0.rc6.vanilla.fc44.x86_64
if kernel_lifecycle_resolve_latest_stable; then exit 1; fi
KERNEL_VANILLA_COPR=@kernel-vanilla/mainline
if kernel_channel_require_platform; then exit 1; fi
python3 - "$ROOT" <<'PY'
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location("upstream", pathlib.Path(sys.argv[1]) / "scripts/kernel/upstream-release.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
def feed(version, moniker="stable"):
    return {"latest_stable": {"version": version}, "releases": [{"version": version, "moniker": moniker, "iseol": False}]}
assert m.latest_stable(feed("7.2.9")) == "7.2.9"
assert m.latest_stable(feed("7.3", "mainline")) == "7.3"
for payload in (feed("7.3-rc6"), feed("7.3.0-rc1"), feed("7.2.9", "linux-next"), {"latest_stable": {"version": "7.2.9"}, "releases": []}):
    try: m.latest_stable(payload)
    except (ValueError, KeyError): pass
    else: raise AssertionError("non-final or missing upstream release accepted")
PY
echo 'kernel channel behavior: PASS'

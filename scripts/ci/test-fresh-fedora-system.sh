#!/usr/bin/env bash
# Exercise the production system-updates module before CI installs its toolchain.
set -Eeuo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
[[ "${CI:-false}" == true && -f /.dockerenv ]] || { echo 'Disposable CI container only' >&2; exit 50; }
grep -Eq '^VERSION_ID="?44"?$' /etc/os-release
source "$REPO_ROOT/lib/bootstrap.sh"
engine_bootstrap
DRY_RUN=false; export DRY_RUN
module_catalog_load "$REPO_ROOT/manifests/module-plan.conf"
orchestrator_run_module system.updates
rpm -q python3 python3-pip python3-devel pipx dmidecode python3-gobject
python3 -m pip --version
venv_root="$(mktemp -d)"
trap 'rm -rf "$venv_root"' EXIT
python3 -m venv "$venv_root/venv"
"$venv_root/venv/bin/python" -c 'import sys; assert sys.version_info.major == 3'
printf 'Fresh Fedora system module: PASS; full installation and hardware remain untested\n'

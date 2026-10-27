#!/usr/bin/env bash
# Real configuration loaders and evidence evaluators, with temporary fixtures.
# shellcheck disable=SC2016,SC2034
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/fixture/scripts/config" "$tmp/evidence"
cp -a "$ROOT/config" "$ROOT/lib" "$tmp/fixture/"
cp "$ROOT/scripts/config/validate-config.sh" "$tmp/fixture/scripts/config/"

# Execute the guide's actual initial configuration block: retain Kickstart
# bytes, and select Fedora 45 when creating a new overlay from the example.
python3 - "$ROOT" "$tmp/fixture" <<'PYCONFIG'
from pathlib import Path
import os, re, subprocess, sys
root, fixture = map(Path, sys.argv[1:])
doc=(root/'docs/INSTALLATION_GUIDE.md').read_text()
blocks=[b for b in re.findall(r'```bash\n(.*?)```',doc,re.S) if 'test -e config/local.conf' in b and '$EDITOR config/local.conf' in b]
assert len(blocks)==1, 'one canonical configuration block is required'
block=blocks[0]
local=fixture/'config/local.conf'
original='HOST_RELEASE="45"\nREAL_MACHINE_APPROVED="false"\n'
local.write_text(original)
subprocess.run(['bash','-eu','-c',block],cwd=fixture,env=os.environ | {'EDITOR':'true'},check=True)
assert local.read_text() == original
local.unlink()
subprocess.run(['bash','-eu','-c',block],cwd=fixture,env=os.environ | {'EDITOR':'true'},check=True)
assert 'HOST_RELEASE="45"' in local.read_text()
PYCONFIG

# Final approval belongs before both dry-run and backup. The actual evidence
# hash changes when that flag changes and stays fixed once configuration freezes.
source "$ROOT/lib/evidence.sh"
REPO_ROOT="$tmp/fixture"
mkdir -p "$REPO_ROOT/manifests" "$REPO_ROOT/installer"
cp "$ROOT/installer/fedora44-media.lock" "$REPO_ROOT/installer/"
before="$(effective_config_sha256)"
sed -i 's/REAL_MACHINE_APPROVED="false"/REAL_MACHINE_APPROVED="true"/' "$REPO_ROOT/config/local.conf"
after="$(effective_config_sha256)"
[[ "$before" != "$after" && "$after" == "$(effective_config_sha256)" ]]

# Borg accepts both SSH syntaxes. Restic backends and ambiguous paths do not.
for repository in /external/borg ssh://backup@nas.example:2222/./borg backup@nas.example:borg; do
  printf 'BACKUP_REPOSITORY="%s"\n' "$repository" > "$tmp/fixture/config/local.conf"
  bash "$ROOT/scripts/config/validate-config.sh" "$tmp/fixture/config" >/dev/null
done
for repository in rest:https://nas/repo s3:bucket/repo relative/path; do
  printf 'BACKUP_REPOSITORY="%s"\n' "$repository" > "$tmp/fixture/config/local.conf"
  if bash "$ROOT/scripts/config/validate-config.sh" "$tmp/fixture/config" >/dev/null 2>&1; then
    echo "Unexpected repository accepted: $repository" >&2; exit 1
  fi
done

# Every public KVM helper executes the validated common loader before reading
# settings. Execute their real preambles against the same local override.
printf 'ROCKY_SERVER_NAME="local-rocky"\n' > "$tmp/fixture/config/local.conf"
python3 - "$ROOT" "$tmp" <<'PY'
from pathlib import Path
import sys
root, tmp = map(Path, sys.argv[1:])
for filename in ('create_rocky_devops_vm.sh', 'configure_nautilus_vm_access.sh'):
    code = (root / 'scripts/kvm' / filename).read_text()
    end = min(pos for key in ('\nusage()', '\nfail()') if (pos := code.find(key)) >= 0)
    preamble = code[:end]
    preamble = '\n'.join(line for line in preamble.splitlines() if not line.startswith('REPO_ROOT='))
    (tmp / filename).write_text(preamble + '\n[[ "$ROCKY_SERVER_NAME" == local-rocky ]]\n')
code = (root / 'diagnostics/final-certification').read_text()
(tmp / 'suspend-count.sh').write_text(code[code.index('suspend_count(){'):code.index('latest_post_resume_log(){')] + code[code.index('record_suspend(){'):code.index('valid_coldstart(){')])
PY
for script in create_rocky_devops_vm.sh configure_nautilus_vm_access.sh; do
  REPO_ROOT="$tmp/fixture" bash "$tmp/$script"
done
printf 'ROCKY_SERVER_NAME="$(touch /tmp/fgc-unexpected-execution)"\n' > "$tmp/fixture/config/local.conf"
if REPO_ROOT="$tmp/fixture" bash "$tmp/create_rocky_devops_vm.sh" >/dev/null 2>&1; then
  echo 'KVM helper accepted executable local configuration' >&2; exit 1
fi

# A transient package mirror failure retries the exact command, at most three
# times. Exhaustion must preserve the non-zero package-manager result.
mkdir -p "$tmp/retry-bin"
cat > "$tmp/retry-bin/dnf5" <<'PKG'
#!/usr/bin/env bash
n=0; [[ ! -r "$RETRY_COUNTER" ]] || n="$(cat "$RETRY_COUNTER")"
n=$((n+1)); echo "$n" > "$RETRY_COUNTER"
printf '%s\n' "$*" >> "$RETRY_ARGS"
(( n >= RETRY_SUCCESS_AFTER )) || exit 37
PKG
printf '#!/usr/bin/env bash\n[[ "$1" == 10 ]]\n' > "$tmp/retry-bin/sleep"
chmod +x "$tmp/retry-bin/"*
export RETRY_COUNTER="$tmp/retry-count" RETRY_ARGS="$tmp/retry-args"
env PATH="$tmp/retry-bin:$PATH" RETRY_SUCCESS_AFTER=3 bash "$ROOT/.github/scripts/dnf-retry.sh" dnf5 --refresh --setopt=gpgcheck=1 install fixture >/dev/null 2>&1
[[ "$(cat "$RETRY_COUNTER")" == 3 && "$(sort -u "$RETRY_ARGS")" == '--refresh --setopt=gpgcheck=1 install fixture' ]]
rm "$RETRY_COUNTER" "$RETRY_ARGS"
rc=0
env PATH="$tmp/retry-bin:$PATH" RETRY_SUCCESS_AFTER=99 bash "$ROOT/.github/scripts/dnf-retry.sh" dnf5 install fixture >/dev/null 2>&1 || rc=$?
[[ "$rc" == 37 && "$(cat "$RETRY_COUNTER")" == 3 ]]

# Count only unique cycles bound to the current configuration, proof chain,
# display and graphics runtime. No simulated cycle certifies real hardware.
source "$ROOT/lib/evidence.sh"
source "$ROOT/lib/validation_gates.sh"
source "$tmp/suspend-count.sh"
evidence_dir="$tmp/evidence"
workstation_runtime_fingerprint() { echo runtime-current; }
effective_config_sha256() { echo config-current; }
hardware_b580_expected_edid_sha256() { echo edid-current; }
validation_imported_proof_path() { echo "gate$1"; }
validation_file_sha256() { echo "hash-$1"; }
validation_require_chain() { [[ "${chain_valid:-true}" == true ]]; }
marker() {
  printf 'fingerprint=runtime-current\neffective_config_sha256=config-current\nlive_proof_sha256=hash-gate2\ndisplay_edid_sha256=edid-current\ndriver_contract=PASS\ncycle_id=%064d\n' "$2" > "$evidence_dir/suspend-$1.ok"
}
marker one 1; marker duplicate 1; marker two 2
[[ "$(suspend_count)" == 2 ]]
for field in fingerprint effective_config_sha256 live_proof_sha256 display_edid_sha256 driver_contract cycle_id; do
  marker two 2
  sed -i "s/^$field=.*/$field=obsolete/" "$evidence_dir/suspend-two.ok"
  [[ "$(suspend_count)" == 1 ]] || { echo "Stale suspend field accepted: $field" >&2; exit 1; }
done
[[ "$(chain_valid=false suspend_count)" == 0 ]]
# Recording a new valid cycle must succeed even with gaps and obsolete files;
# its cycle-derived filename cannot overwrite another valid cycle.
REPO_ROOT="$tmp/record-fixture"; HOME="$tmp/home"
mkdir -p "$REPO_ROOT/diagnostics" "$HOME/.local/state/fedora-gnome-custom"
for doctor in kernel graphics display storage hardware-components driver usb-resume performance; do
  printf '#!/usr/bin/env bash\nexit 0\n' > "$REPO_ROOT/diagnostics/$doctor-doctor"
  chmod +x "$REPO_ROOT/diagnostics/$doctor-doctor"
done
printf 'post resume\n' > "$tmp/resume-unique.log"
printf 'display repair\n' > "$HOME/.local/state/fedora-gnome-custom/display-repair-last.txt"
latest_post_resume_log() { echo "$tmp/resume-unique.log"; }
require_baremetal() { :; }; require_validation_chain() { :; }
final_fingerprint() { workstation_runtime_fingerprint; }
kernel_journal_require_clean() { :; }
ui_check() { printf '%s\n' "$*"; }
record_suspend
[[ "$(suspend_count)" == 2 ]]
echo 'Pre-install configuration and suspend evidence behavior: PASS'

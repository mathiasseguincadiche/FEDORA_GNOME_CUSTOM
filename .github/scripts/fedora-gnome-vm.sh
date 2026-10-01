#!/usr/bin/env bash
# Runs ONLY on an ephemeral GitHub runner, never on the operator's PC.
set -Eeuo pipefail
umask 077
[[ "${GITHUB_ACTIONS:-}" == true && -n "${GITHUB_WORKSPACE:-}" ]] || {
  echo 'This disposable laboratory requires a GitHub Actions runner.' >&2; exit 50;
}
ROOT="$GITHUB_WORKSPACE"
LAB="$ROOT/.fedora-gnome-lab"
[[ ! -e "$LAB" ]] || { echo 'Refusing to reuse an existing lab directory.' >&2; exit 50; }
mkdir -p "$LAB/evidence"
REPORT="$LAB/report.json"
REPORTER="$ROOT/.github/scripts/fedora-lab-report.py"
COMMIT="$(git -C "$ROOT" rev-parse HEAD)"
python3 "$REPORTER" "$REPORT" init "$COMMIT"
# shellcheck source=.github/fedora44-cloud.lock
source "$ROOT/.github/fedora44-cloud.lock"
# shellcheck source=lib/backup_runtime.sh
source "$ROOT/lib/backup_runtime.sh"
SSH_KEY="$LAB/id_ed25519"
SSH_PORT=2223
DISK_BYTES=10737418240  # 10 GiB virtual disk; enough for the GNOME-only fixture.
SSH_OPTS=(-i "$SSH_KEY" -p "$SSH_PORT" -o BatchMode=yes -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o ServerAliveInterval=10 -o ServerAliveCountMax=3)
SCP_OPTS=(-i "$SSH_KEY" -P "$SSH_PORT" -o BatchMode=yes -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5)
VM_PID=''
TPM_PID=''
PHASE=initial
# Fixed lab commands intentionally expand here before being sent over SSH.
# shellcheck disable=SC2029
guest() { ssh "${SSH_OPTS[@]}" lab@127.0.0.1 "$@"; }
# COMMIT is validated by initialize(), and the command is fixed in this file.
guest_action() {
  # shellcheck disable=SC2029
  guest "sudo bash /opt/fgc-lab/repo/.github/scripts/fedora-gnome-guest.sh $1 $COMMIT"
}
mark() { python3 "$REPORTER" "$REPORT" pass "$1"; }
evidence() { python3 "$REPORTER" "$REPORT" evidence "$1" "$2"; }
collect() {
  if guest true >/dev/null 2>&1; then
    guest 'sudo journalctl --no-pager -b' > "$LAB/evidence/$PHASE-early-journal.log" 2> "$LAB/evidence/$PHASE-early-journal.err" || true
    if guest_action collect; then
      scp "${SCP_OPTS[@]}" lab@127.0.0.1:/tmp/fgc-evidence.tar.gz \
        "$LAB/evidence/$PHASE.tar.gz" || true
    fi
  fi
}
cleanup() {
  local rc=$?
  trap - EXIT
  if (( rc != 0 )); then
    python3 "$REPORTER" "$REPORT" fail || true
    collect || true
  fi
  if [[ -n "$VM_PID" ]]; then kill "$VM_PID" 2>/dev/null || true; wait "$VM_PID" 2>/dev/null || true; fi
  if [[ -n "$TPM_PID" ]]; then kill "$TPM_PID" 2>/dev/null || true; wait "$TPM_PID" 2>/dev/null || true; fi
  # Keys, user-data, VM disks and Borg chunks are never uploaded.
  rm -f "$SSH_KEY" "$SSH_KEY.pub" "$LAB/user-data"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  qemu-system-x86 qemu-utils cloud-image-utils ovmf swtpm openssh-client \
  curl ca-certificates gnupg borgbackup jq python3
cd "$LAB"
curl --fail --location --proto '=https' --proto-redir '=https' --retry 4 \
  -o "$FEDORA_CLOUD_IMAGE" "$FEDORA_CLOUD_URL/$FEDORA_CLOUD_IMAGE"
curl --fail --location --proto '=https' --proto-redir '=https' --retry 4 \
  -o "$FEDORA_CLOUD_CHECKSUM" "$FEDORA_CLOUD_URL/$FEDORA_CLOUD_CHECKSUM"
curl --fail --location --proto '=https' --proto-redir '=https' --retry 4 \
  -o fedora.pgp https://fedoraproject.org/fedora.pgp
mkdir -m 700 gnupg
gpg --homedir "$LAB/gnupg" --batch --import fedora.pgp
# Export ONLY the independently pinned Fedora 44 key into the verification ring.
gpg --homedir "$LAB/gnupg" --batch --export "$FEDORA_SIGNING_FINGERPRINT" > fedora44.gpg
[[ -s fedora44.gpg ]]
gpgv --keyring "$LAB/fedora44.gpg" --status-fd 2 --output signed-checksums.txt \
  "$FEDORA_CLOUD_CHECKSUM" 2> "$LAB/evidence/signature.log"
grep -Fq "[GNUPG:] VALIDSIG $FEDORA_SIGNING_FINGERPRINT " "$LAB/evidence/signature.log"
python3 - "$FEDORA_CLOUD_IMAGE" "$FEDORA_CLOUD_SHA256" <<'PY'
import pathlib, re, sys
image, sha = sys.argv[1:]
text = pathlib.Path("signed-checksums.txt").read_text()
if not re.search(r"^SHA256 \(" + re.escape(image) + r"\) = " + sha + r"$", text, re.M):
    raise SystemExit("the signed image/hash pair differs from the lock")
PY
printf '%s  %s\n' "$FEDORA_CLOUD_SHA256" "$FEDORA_CLOUD_IMAGE" | sha256sum --check
qemu-img check "$FEDORA_CLOUD_IMAGE"
mark image
evidence image_sha256 "$FEDORA_CLOUD_SHA256"
# Fetch reviewed bytes on the runner and transfer them to the guest. Both
# sides enforce the lock hashes; guest TLS verification is never disabled.
# shellcheck source=config/gnome-extensions.lock
source "$ROOT/config/gnome-extensions.lock"
mkdir extensions
for prefix in DING SHOW_DESKTOP_PLUS RESOURCE_MONITOR; do
  url_key="${prefix}_SOURCE_URL"
  sha_key="${prefix}_SHA256"
  curl --fail --location --proto '=https' --proto-redir '=https' --retry 3 \
    "${!url_key}" -o "extensions/$prefix.zip"
  printf '%s  %s\n' "${!sha_key}" "extensions/$prefix.zip" | sha256sum --check
done
tar -czf extensions.tar.gz extensions
git -C "$ROOT" archive "$COMMIT" | gzip > repo.tar.gz
ssh-keygen -q -t ed25519 -N '' -f "$SSH_KEY"
PUBKEY="$(cat "$SSH_KEY.pub")"
cat > user-data <<EOF
#cloud-config
users:
  - name: lab
    groups: [wheel]
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $PUBKEY
ssh_pwauth: false
disable_root: true
preserve_hostname: true
write_files:
  - path: /etc/fgc-ci-lab
    content: disposable GitHub Actions VM
EOF
cat > meta-data <<'EOF'
instance-id: fgc-fedora-ci
EOF
cloud-localds seed.img user-data meta-data
OVMF_CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
OVMF_VARS=/usr/share/OVMF/OVMF_VARS_4M.fd
[[ -r "$OVMF_CODE" && -r "$OVMF_VARS" ]]
ACCEL=tcg
CPU=max
if [[ -e /dev/kvm ]]; then
  sudo chown "$(id -u):$(id -g)" /dev/kvm
  [[ -r /dev/kvm && -w /dev/kvm ]] && { ACCEL=kvm; CPU=host; }
fi
evidence accelerator "$ACCEL"
new_bundle() {
  backup_runtime_require_staging_space "$LAB" "$DISK_BYTES" 2147483648
  mkdir -p "$1/tpm"
  cp --sparse=always "$FEDORA_CLOUD_IMAGE" "$1/disk.qcow2"
  qemu-img resize "$1/disk.qcow2" 10G
  cp "$OVMF_VARS" "$1/nvram.fd"
}
start_vm() {
  local bundle="$1" restricted="$2"
  [[ -z "$VM_PID" && -z "$TPM_PID" ]]
  rm -f "$LAB/swtpm.sock"
  swtpm socket --tpm2 --tpmstate "dir=$bundle/tpm" \
    --ctrl "type=unixio,path=$LAB/swtpm.sock" --flags not-need-init --terminate \
    > "$LAB/evidence/$PHASE-swtpm.log" 2>&1 &
  TPM_PID=$!
  for _ in {1..50}; do [[ -S "$LAB/swtpm.sock" ]] && break; sleep 0.1; done
  [[ -S "$LAB/swtpm.sock" ]]
  qemu-system-x86_64 -name fgc-fedora-ci -machine "q35,accel=$ACCEL" -cpu "$CPU" \
    -smp 2 -m 4096 -device virtio-vga -device qemu-xhci -device usb-tablet \
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" \
    -drive "if=pflash,format=raw,file=$bundle/nvram.fd" \
    -drive "file=$bundle/disk.qcow2,format=qcow2,if=virtio" \
    -drive "file=$LAB/seed.img,format=raw,if=virtio,readonly=on" \
    -device virtio-net-pci,netdev=net0 \
    -netdev "user,id=net0,restrict=$restricted,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22" \
    -chardev "socket,id=chrtpm,path=$LAB/swtpm.sock" \
    -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0 \
    -display none -serial "file:$LAB/evidence/$PHASE-console.log" \
    > "$LAB/evidence/$PHASE-qemu.log" 2>&1 &
  VM_PID=$!
}
wait_ssh() {
  for _ in {1..180}; do
    kill -0 "$VM_PID" 2>/dev/null || { cat "$LAB/evidence/$PHASE-qemu.log"; return 1; }
    if guest true >/dev/null 2>&1; then return 0; fi
    sleep 5
  done
  return 1
}
wait_session() {
  for _ in {1..90}; do
    if guest_action ready >/dev/null 2>&1; then return 0; fi
    sleep 5
  done
  guest_action ready
  return 1
}
provision() {
  wait_ssh
  guest 'sudo cloud-init status --wait --long'
  # Set the disposable hostname after cloud-init; no hostnamed service is needed.
  guest "sudo python3 -c 'import socket; socket.sethostname(b\"fgc-fedora-ci\")'"
  guest "printf '%s\\n' fgc-fedora-ci | sudo tee /etc/hostname >/dev/null"
  scp "${SCP_OPTS[@]}" repo.tar.gz lab@127.0.0.1:/tmp/
  guest 'sudo mkdir -p /opt/fgc-lab/repo && sudo tar -C /opt/fgc-lab/repo -xzf /tmp/repo.tar.gz'
  # shellcheck disable=SC2029
  guest "printf '%s\n' '$COMMIT' | sudo tee /opt/fgc-lab/repo/CI_COMMIT >/dev/null"
  scp "${SCP_OPTS[@]}" extensions.tar.gz lab@127.0.0.1:/tmp/
  guest 'sudo tar -C /opt/fgc-lab -xzf /tmp/extensions.tar.gz && sudo chown -R lab:lab /opt/fgc-lab/extensions'
  guest_action install
  wait_session
}
shutdown_vm() {
  # Connection may close before systemctl's reply. The actual process exit is required.
  guest 'sudo systemctl poweroff' || true
  for _ in {1..90}; do
    if ! kill -0 "$VM_PID" 2>/dev/null; then
      wait "$VM_PID"
      VM_PID=''
      wait "$TPM_PID"
      TPM_PID=''
      return 0
    fi
    sleep 2
  done
  echo 'VM did not shut down cleanly; refusing a live disk archive.' >&2
  return 1
}
boot_id() { guest cat /proc/sys/kernel/random/boot_id; }

PHASE=initial
new_bundle "$LAB/original"
start_vm "$LAB/original" off
provision 2>&1 | tee "$LAB/evidence/install.log"
evidence boot_id "$(boot_id)"
mark boot
guest_action session 2>&1 | tee "$LAB/evidence/gnome.log"
guest_action health
mark gnome
guest_action seed 2>&1 | tee "$LAB/evidence/borg-files.log"
evidence files_archive_id "$(guest 'sudo cat /var/lib/fgc-lab/files-archive.txt' | awk '{print $2}')"
scp "${SCP_OPTS[@]}" lab@127.0.0.1:/tmp/fgc-files-recovery.tar.gz files-recovery.tar.gz
mark borg_files
collect

PHASE=reboot
old_boot="$(boot_id)"
guest 'sudo systemctl reboot' || true
# Require a changed kernel boot ID, not just an SSH reconnection.
for _ in {1..180}; do
  current="$(boot_id 2>/dev/null || true)"
  [[ -n "$current" && "$current" != "$old_boot" ]] && break
  sleep 5
done
[[ -n "$current" && "$current" != "$old_boot" ]]
wait_session
guest_action persistent 2>&1 | tee "$LAB/evidence/reboot.log"
evidence reboot_id "$current"
guest_action health
collect
mark reboot
shutdown_vm

PHASE=cold-archive
qemu-img check original/disk.qcow2
# All members are offline: qcow2 + UEFI vars + TPM state, with no backing chain.
qemu-img info --output=json original/disk.qcow2 | jq -e '."backing-filename" == null'
find original -type f -print0 | sort -z | xargs -0 sha256sum > "$LAB/evidence/cold-members.sha256"
evidence disk_sha256 "$(sha256sum original/disk.qcow2 | awk '{print $1}')"
evidence nvram_sha256 "$(sha256sum original/nvram.fd | awk '{print $1}')"
# Logical bytes bound the archive and extraction, including sparse members.
required="$(find original -type f -printf '%s\n' | awk '{n+=$1} END {printf "%.0f",n}')"
backup_runtime_require_staging_space "$LAB" "$required" 2147483648
backup_engine_require
backup_engine_env "$LAB/cold-repository"
backup_engine_init
# VM fixture, not a production full-backup certification marker.
identity="$(backup_engine_create full -- original)"
read -r archive aid <<<"$identity"
backup_engine_archive_matches "$archive" "$aid" full
backup_engine_check full "$archive"
evidence cold_archive "$archive"
evidence cold_archive_id "$aid"
evidence encryption none
# Remove only this throwaway CI source after the archive has been verified.
# No original disk/state is then available to accidentally boot or compare.
rm -rf -- "$LAB/original"
backup_runtime_require_staging_space "$LAB" "$required" 2147483648
mkdir recovered
backup_engine_extract "$archive" "$LAB/recovered"
(cd recovered && sha256sum --check "$LAB/evidence/cold-members.sha256")
qemu-img check recovered/original/disk.qcow2
mark cold_archive

PHASE=restored
start_vm "$LAB/recovered/original" on
wait_ssh
wait_session
guest_action recovered 2>&1 | tee "$LAB/evidence/restored.log"
guest_action health
evidence restored_boot_id "$(boot_id)"
evidence recovery_network restrict=on
evidence tpm_canary PASS
collect
mark restored_vm
shutdown_vm
# Boot and TPM/data checks are complete; retain evidence, free disposable images.
rm -rf -- "$LAB/recovered" "$LAB/cold-repository"

PHASE=rebuilt
new_bundle "$LAB/rebuilt"
start_vm "$LAB/rebuilt" off
# A second clean image installs packages independently; no old system disk is used.
provision 2>&1 | tee "$LAB/evidence/rebuild-install.log"
scp "${SCP_OPTS[@]}" files-recovery.tar.gz lab@127.0.0.1:/tmp/fgc-files-recovery.tar.gz
guest_action rebuild 2>&1 | tee "$LAB/evidence/rebuilt.log"
guest_action session
rebuilt_initial="$(boot_id)"
guest 'sudo systemctl reboot' || true
for _ in {1..180}; do
  current="$(boot_id 2>/dev/null || true)"
  [[ -n "$current" && "$current" != "$rebuilt_initial" ]] && break
  sleep 5
done
[[ -n "$current" && "$current" != "$rebuilt_initial" ]]
wait_session
guest_action rebuilt-check
guest_action session
guest_action health
evidence rebuilt_boot_id "$(boot_id)"
collect
mark rebuilt_os
shutdown_vm
python3 "$REPORTER" "$REPORT" finalize
cat "$REPORT"

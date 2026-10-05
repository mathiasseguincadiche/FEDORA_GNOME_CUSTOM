#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
LAB="$ROOT/.vm-pretest"
IMAGE_BASE_URL="https://dl.rockylinux.org/pub/rocky/10.2/images/x86_64"
IMAGE_NAME="Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2"
SSH_PORT="2222"
VM_USER="mathias"
REPORT="$LAB/report.txt"
CONSOLE="$LAB/console.log"
BOOTSTRAP_LOG="$LAB/bootstrap.log"
VERIFY_LOG="$LAB/verify.log"
PIDFILE="$LAB/qemu.pid"
QGA_SOCKET="$LAB/qga.sock"
SSH_KEY="$LAB/id_ed25519"
SSH_OPTS=(-i "$SSH_KEY" -p "$SSH_PORT" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)
SCP_OPTS=(-i "$SSH_KEY" -P "$SSH_PORT" -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)

mkdir -p "$LAB"
: > "$REPORT"
report() { printf '%s\n' "$*" | tee -a "$REPORT"; }
cleanup() {
  if [[ -s "$PIDFILE" ]]; then
    kill "$(cat "$PIDFILE")" 2>/dev/null || true
  fi
  rm -f "$QGA_SOCKET"
}
trap cleanup EXIT
report '=== FEDORA_GNOME_CUSTOM REAL ROCKY LINUX 10.2 VM PRE-TEST ==='
report "commit=${GITHUB_SHA:-local}"

report '[1/10] Host VM dependencies'
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  qemu-system-x86 qemu-utils cloud-image-utils openssh-client curl ca-certificates \
  gnupg dnsutils ovmf borgbackup jq >/dev/null

report '[2/10] Authenticate Rocky production cloud image'
cd "$LAB"
curl -fL --retry 4 --retry-delay 3 -o "$IMAGE_NAME" "$IMAGE_BASE_URL/$IMAGE_NAME"
curl -fL --retry 4 --retry-delay 3 -o CHECKSUM "$IMAGE_BASE_URL/CHECKSUM"
curl -fL --retry 4 --retry-delay 3 -o CHECKSUM.asc "$IMAGE_BASE_URL/CHECKSUM.asc"
bash "$ROOT/scripts/kvm/verify_rocky_cloud_image.sh" --image "$LAB/$IMAGE_NAME" --sha256sums "$LAB/CHECKSUM" --signature "$LAB/CHECKSUM.asc" | tee -a "$REPORT"

report '[3/10] cloud-init + disk'
ssh-keygen -q -t ed25519 -N '' -f "$SSH_KEY"
PUBKEY="$(cat "$SSH_KEY.pub")"
cat > user-data <<EOF
#cloud-config
users:
  - default
  - name: $VM_USER
    groups: [wheel]
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $PUBKEY
ssh_pwauth: false
disable_root: true
EOF
cat > meta-data <<'EOF'
instance-id: fedora-gnome-custom-ci
local-hostname: rocky-devops-ci
EOF
cloud-localds seed.img user-data meta-data
cp "$IMAGE_NAME" disk.qcow2
qemu-img resize disk.qcow2 40G >/dev/null
qemu-img check disk.qcow2

# Exercise Q35 + UEFI, matching the production guest architecture.
OVMF_CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
[[ -r "$OVMF_CODE" && -r /usr/share/OVMF/OVMF_VARS_4M.fd ]]
cp /usr/share/OVMF/OVMF_VARS_4M.fd nvram.fd
report '[4/10] KVM or TCG acceleration'
ACCEL=tcg
QEMU_CPU=max
if [[ -e /dev/kvm ]]; then
  sudo chmod 666 /dev/kvm || true
  if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    ACCEL=kvm
    QEMU_CPU=host
  fi
fi
report "selected_acceleration=$ACCEL"
start_vm() {
  rm -f "$QGA_SOCKET"
  qemu-system-x86_64 -name rocky-devops-ci -machine "q35,accel=$1" -cpu "$2" -smp 2 -m 6144 \
    -drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE" -drive if=pflash,format=raw,file=nvram.fd \
    -drive file=disk.qcow2,format=qcow2,if=virtio -drive file=seed.img,format=raw,if=virtio,readonly=on \
    -device virtio-net-pci,netdev=net0 -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22" \
    -device virtio-serial-pci \
    -chardev "socket,id=qga0,path=$QGA_SOCKET,server=on,wait=off" \
    -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
    -display none -serial "file:$CONSOLE" -daemonize -pidfile "$PIDFILE"
}
if ! start_vm "$ACCEL" "$QEMU_CPU"; then
  [[ "$ACCEL" == kvm ]] || exit 21
  ACCEL=tcg
  QEMU_CPU=max
  start_vm "$ACCEL" "$QEMU_CPU"
fi
report "active_acceleration=$ACCEL"

report '[5/10] SSH + cloud-init'
ready=0
for _ in $(seq 1 120); do
  if ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" true >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 5
done
if (( ready != 1 )); then
  tail -n 200 "$CONSOLE" | tee -a "$REPORT"
  exit 22
fi
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'sudo cloud-init status --wait --long'

report '[6/10] Rocky Linux 10.2 + network'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'test "$(uname -m)" = x86_64 && test "$(getenforce)" = Enforcing && grep -q "^ID=\"rocky\"" /etc/os-release'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" "grep -q '^VERSION_ID=\"10.2\"' /etc/os-release"
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'getent hosts github.com >/dev/null && curl -fsSI --max-time 20 https://github.com >/dev/null'

report '[7/10] Copy exact repository guest bootstrap'
scp "${SCP_OPTS[@]}" "$ROOT/guest/rocky-devops/bootstrap-devops.sh" "$ROOT/guest/rocky-devops/verify-devops.sh" "$VM_USER@127.0.0.1:/tmp/"
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'chmod +x /tmp/bootstrap-devops.sh /tmp/verify-devops.sh'

report '[8/10] Execute real DevOps bootstrap'
# shellcheck disable=SC2029
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" "sudo env DEVOPS_USER=$VM_USER /tmp/bootstrap-devops.sh" 2>&1 | tee "$BOOTSTRAP_LOG"

report '[9/10] Full runtime verification + application toolchain smoke'
# shellcheck disable=SC2029
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" "sudo env DEVOPS_USER=$VM_USER /tmp/verify-devops.sh" 2>&1 | tee "$VERIFY_LOG"
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'docker run --rm hello-world >/dev/null && docker compose version >/dev/null'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'node -e '\''if (Number(process.versions.node.split(".")[0]) < 22) process.exit(1)'\'' && npm --version >/dev/null && corepack --version >/dev/null'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'cat >/tmp/Hello.java <<'\''EOF'\''
public class Hello { public static void main(String[] args) { System.out.print("java-smoke"); } }
EOF
cd /tmp && javac Hello.java && test "$(java Hello)" = java-smoke && mvn -version >/dev/null'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'glab version >/dev/null && minikube version --short >/dev/null && test "$(minikube config get driver)" = docker'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'yq -n '\''.ready = true'\'' | grep -q '\''ready: true'\'' && k9s version --short >/dev/null && kubectx --help >/dev/null && kubens --help >/dev/null'

report '[10/10] Reboot persistence and isolated cold restoration'
boot_before="$(ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'cat /proc/sys/kernel/random/boot_id')"
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'sudo systemctl reboot' || true
ready=0
for _ in $(seq 1 120); do
  boot_after="$(ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null || true)"
# shellcheck disable=SC2029
  if [[ -n "$boot_after" && "$boot_before" != "$boot_after" ]] && ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" "sudo env DEVOPS_USER=$VM_USER /tmp/verify-devops.sh" >>"$VERIFY_LOG" 2>&1; then ready=1; break; fi
  sleep 5
done
((ready == 1)) || { report 'FAIL: actual reboot or complete toolchain recovery failed'; exit 23; }
report "boot_id_before=$boot_before"
report "boot_id_after=$boot_after"
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'printf "rocky-restoration-proof\n" > ~/restoration-proof.txt; sync; sudo systemctl poweroff' || true
stopped=0
for _ in $(seq 1 90); do
  if ! kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then stopped=1; break; fi
  sleep 2
done
((stopped == 1)) || { report 'FAIL: VM must be stopped before cold archive'; exit 24; }
qemu-img check disk.qcow2
# Borg never reads a running guest disk. This runner's restored VM exposes SSH
# only on localhost; no libvirt production LAN, host share or original VM runs.
mkdir cold-stage
mv disk.qcow2 nvram.fd seed.img cold-stage/
(cd cold-stage; sha256sum disk.qcow2 nvram.fd seed.img > SHA256SUMS)
borg init --encryption=none "$LAB/borg"
borg create --stats "$LAB/borg::rocky-cold" cold-stage
borg check --verify-data "$LAB/borg::rocky-cold"
rm -rf cold-stage
mkdir restored
(cd restored; borg extract "$LAB/borg::rocky-cold")
(cd restored/cold-stage; sha256sum -c SHA256SUMS)
mv restored/cold-stage/disk.qcow2 restored/cold-stage/nvram.fd restored/cold-stage/seed.img .
report 'cold_archive=PASS encryption=none source_disks_deleted=true'
start_vm "$ACCEL" "$QEMU_CPU"
ready=0
for _ in $(seq 1 120); do
# shellcheck disable=SC2029
  if ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'test "$(cat ~/restoration-proof.txt)" = rocky-restoration-proof' >/dev/null 2>&1 &&
     ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" "sudo env DEVOPS_USER=$VM_USER /tmp/verify-devops.sh" >>"$VERIFY_LOG" 2>&1; then ready=1; break; fi
  sleep 5
done
((ready == 1)) || { report 'FAIL: restored Rocky VM/data/toolchain qualification failed'; exit 25; }
report 'restored_vm=PASS data=PASS toolchain=PASS'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'sudo systemctl --failed --no-legend; sudo journalctl -b -p err --no-pager; sudo cat /var/lib/fedora-gnome-custom/rocky-devops-packages.txt' | tee "$LAB/guest-health.log"
# Unexpected failed units make the qualification fail; raw errors are retained.
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'test -z "$(systemctl --failed --no-legend)"'
report 'VERDICT: REAL ROCKY LINUX 10.2 READY-TO-WORK DEVOPS VM PRE-TEST PASS'

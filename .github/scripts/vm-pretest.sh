#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
LAB="$ROOT/.vm-pretest"
IMAGE_BASE_URL="https://cloud-images.ubuntu.com/releases/26.04/release"
IMAGE_NAME="ubuntu-26.04-server-cloudimg-amd64.img"
SSH_PORT="2222"
VM_USER="mathias"
REPORT="$LAB/report.txt"
CONSOLE="$LAB/console.log"
BOOTSTRAP_LOG="$LAB/bootstrap.log"
VERIFY_LOG="$LAB/verify.log"
PIDFILE="$LAB/qemu.pid"
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
}
trap cleanup EXIT
report '=== FEDORA_GNOME_CUSTOM REAL UBUNTU 26.04 VM PRE-TEST ==='
report "commit=${GITHUB_SHA:-local}"

report '[1/10] Host VM dependencies'
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  qemu-system-x86 qemu-utils cloud-image-utils openssh-client curl ca-certificates \
  gnupg ubuntu-cloudimage-keyring dnsutils >/dev/null

report '[2/10] Authenticate Canonical cloud image'
cd "$LAB"
curl -fL --retry 4 --retry-delay 3 -o "$IMAGE_NAME" "$IMAGE_BASE_URL/$IMAGE_NAME"
curl -fL --retry 4 --retry-delay 3 -o SHA256SUMS "$IMAGE_BASE_URL/SHA256SUMS"
curl -fL --retry 4 --retry-delay 3 -o SHA256SUMS.gpg "$IMAGE_BASE_URL/SHA256SUMS.gpg"
gpgv --keyring /usr/share/keyrings/ubuntu-cloudimage-keyring.gpg SHA256SUMS.gpg SHA256SUMS
expected="$(awk -v n="$IMAGE_NAME" '$2==n || $2=="*"n {print $1; exit}' SHA256SUMS)"
[[ "$expected" =~ ^[0-9a-fA-F]{64}$ ]]
printf '%s  %s\n' "$expected" "$IMAGE_NAME" | sha256sum -c -

report '[3/10] cloud-init + disk'
ssh-keygen -q -t ed25519 -N '' -f "$SSH_KEY"
PUBKEY="$(cat "$SSH_KEY.pub")"
cat > user-data <<EOF
#cloud-config
users:
  - default
  - name: $VM_USER
    groups: [adm, sudo]
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $PUBKEY
ssh_pwauth: false
disable_root: true
EOF
cat > meta-data <<'EOF'
instance-id: fedora-gnome-custom-ci
local-hostname: ubuntu-devops-ci
EOF
cloud-localds seed.img user-data meta-data
cp "$IMAGE_NAME" disk.qcow2
qemu-img resize disk.qcow2 40G >/dev/null
qemu-img check disk.qcow2

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
  qemu-system-x86_64 -name ubuntu-devops-ci -machine "accel=$1" -cpu "$2" -smp 2 -m 4096 \
    -drive file=disk.qcow2,format=qcow2,if=virtio -drive file=seed.img,format=raw,if=virtio,readonly=on \
    -device virtio-net-pci,netdev=net0 -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22" \
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

report '[6/10] Ubuntu 26.04 + network'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" "grep -q '^VERSION_ID=\"26.04\"' /etc/os-release"
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'getent hosts github.com >/dev/null && curl -fsSI --max-time 20 https://github.com >/dev/null'

report '[7/10] Copy exact repository guest bootstrap'
scp "${SCP_OPTS[@]}" "$ROOT/guest/ubuntu-devops/bootstrap-devops.sh" "$ROOT/guest/ubuntu-devops/verify-devops.sh" "$VM_USER@127.0.0.1:/tmp/"
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'chmod +x /tmp/bootstrap-devops.sh /tmp/verify-devops.sh'

report '[8/10] Execute real DevOps bootstrap'
# shellcheck disable=SC2029
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" "sudo env DEVOPS_USER=$VM_USER /tmp/bootstrap-devops.sh" 2>&1 | tee "$BOOTSTRAP_LOG"

report '[9/10] Runtime verification + Docker smoke'
# shellcheck disable=SC2029
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" "sudo env DEVOPS_USER=$VM_USER /tmp/verify-devops.sh" 2>&1 | tee "$VERIFY_LOG"
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'docker run --rm hello-world >/dev/null'

report '[10/10] Reboot persistence'
ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'sudo reboot' || true
sleep 10
ready=0
for _ in $(seq 1 90); do
  if ssh "${SSH_OPTS[@]}" "$VM_USER@127.0.0.1" 'docker --version >/dev/null && terraform version >/dev/null && kubectl version --client=true >/dev/null && systemctl is-active --quiet docker' >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 5
done
if (( ready != 1 )); then
  report 'FAIL: VM did not recover after reboot'
  exit 23
fi
report 'VERDICT: REAL UBUNTU 26.04 DEVOPS VM PRE-TEST PASS'

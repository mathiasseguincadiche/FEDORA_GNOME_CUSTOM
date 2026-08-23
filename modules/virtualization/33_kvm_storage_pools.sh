#!/usr/bin/env bash
set -Eeuo pipefail

kvm_storage_validate_mount() {
  local mount="${KVM_DATA_MOUNT:-/data}" target fstype root_source data_source
  target="$(findmnt -n -T "$mount" -o TARGET 2>/dev/null || true)"
  fstype="$(findmnt -n -T "$mount" -o FSTYPE 2>/dev/null || true)"
  [[ "$target" == "$mount" ]] || { log_error KVM "$mount must be a dedicated mountpoint"; return 1; }
  [[ "$fstype" == "${KVM_DATA_FSTYPE:-ext4}" ]] || { log_error KVM "$mount must use ${KVM_DATA_FSTYPE:-ext4}, detected ${fstype:-unknown}"; return 1; }
  root_source="$(findmnt -n -T / -o SOURCE 2>/dev/null || true)"
  data_source="$(findmnt -n -T "$mount" -o SOURCE 2>/dev/null || true)"
  [[ -n "$data_source" && "$data_source" != "$root_source" ]] || { log_error KVM 'virtualization storage must not share the root filesystem source'; return 1; }
}

kvm_storage_precheck() {
  is_true "${ENABLE_KVM:-true}" || return 0
  if ! command_exists findmnt || ! command_exists lsblk; then return "$EXIT_PRECHECK_FAILED"; fi
  if is_true "${KVM_REQUIRE_DEDICATED_STORAGE:-true}"; then
    kvm_storage_validate_mount || return "$EXIT_PRECHECK_FAILED"
  fi
  [[ "${KVM_POOL_PATH:-}" == "${KVM_DATA_MOUNT:-/data}"/* ]] || {
    log_error KVM 'KVM_POOL_PATH must live below the dedicated KVM data mount'
    return "$EXIT_PRECHECK_FAILED"
  }
}

kvm_storage_plan() {
  cat <<'EOF'
DEDICATED KVM STORAGE:
- require the second virtualization SSD to be mounted manually at /data as EXT4
- never partition or format any disk
- create /data/libvirt/{images,iso,cloud-init,nvram,snapshots,exports,shared}
- persist a SELinux virt_image_t file-context rule and restore labels
- define/start/autostart the devops-data directory pool idempotently
- keep VM system disks in qcow2 unless a profile explicitly documents another format
EOF
}

kvm_storage_apply() {
  local root="${KVM_DATA_MOUNT:-/data}/libvirt" pool="${KVM_POOL_NAME:-devops-data}" path="${KVM_POOL_PATH:-/data/libvirt/images}"
  local selinux_type="${KVM_STORAGE_SELINUX_TYPE:-virt_image_t}" pattern
  is_true "${ENABLE_KVM:-true}" || return 0

  run_mutating KVM sudo install -d -m 0755 "$root" "$root/images" "$root/iso" "$root/cloud-init" "$root/nvram" "$root/snapshots" "$root/exports" "$root/shared" || return "$EXIT_APPLY_FAILED"

  pattern="${root}(/.*)?"
  if is_true "${DRY_RUN:-true}"; then
    run_mutating KVM sudo semanage fcontext -a -t "$selinux_type" "$pattern" || return "$EXIT_APPLY_FAILED"
    run_mutating KVM sudo restorecon -R "$root" || return "$EXIT_APPLY_FAILED"
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-define-as "$pool" dir --target "$path" || return "$EXIT_APPLY_FAILED"
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-start "$pool" || return "$EXIT_APPLY_FAILED"
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-autostart "$pool" || return "$EXIT_APPLY_FAILED"
    return 0
  fi

  if sudo semanage fcontext -l 2>/dev/null | grep -Fq "$root"; then
    run_mutating KVM sudo semanage fcontext -m -t "$selinux_type" "$pattern" || return "$EXIT_APPLY_FAILED"
  else
    run_mutating KVM sudo semanage fcontext -a -t "$selinux_type" "$pattern" || return "$EXIT_APPLY_FAILED"
  fi
  run_mutating KVM sudo restorecon -R "$root" || return "$EXIT_APPLY_FAILED"

  if ! sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-info "$pool" >/dev/null 2>&1; then
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-define-as "$pool" dir --target "$path" || return "$EXIT_APPLY_FAILED"
  fi
  if ! sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-info "$pool" 2>/dev/null | grep -Eq '^State:[[:space:]]+running'; then
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-start "$pool" || return "$EXIT_APPLY_FAILED"
  fi
  if is_true "${KVM_POOL_AUTOSTART:-true}"; then
    run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-autostart "$pool" || return "$EXIT_APPLY_FAILED"
  fi
  run_mutating KVM sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-refresh "$pool" || return "$EXIT_APPLY_FAILED"
}

kvm_storage_postcheck() {
  local root="${KVM_DATA_MOUNT:-/data}/libvirt" pool="${KVM_POOL_NAME:-devops-data}"
  is_true "${DRY_RUN:-true}" && return 0
  is_true "${ENABLE_KVM:-true}" || return 0
  kvm_storage_validate_mount || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-info "$pool" | grep -Eq '^State:[[:space:]]+running' || return "$EXIT_POSTCHECK_FAILED"
  sudo virsh --connect "${LIBVIRT_URI:-qemu:///system}" pool-info "$pool" | grep -Eq '^Autostart:[[:space:]]+yes' || return "$EXIT_POSTCHECK_FAILED"
  ls -Zd "$root/images" 2>/dev/null | grep -Fq "${KVM_STORAGE_SELINUX_TYPE:-virt_image_t}" || {
    log_error KVM 'libvirt storage SELinux label is not correct'
    return "$EXIT_POSTCHECK_FAILED"
  }
}

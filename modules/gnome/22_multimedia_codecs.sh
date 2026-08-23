#!/usr/bin/env bash
set -Eeuo pipefail

multimedia_arc_b580_present() {
  lspci -Dn 2>/dev/null | grep -Eqi '030[02]:[[:space:]]+8086:e20b'
}

multimedia_vainfo() {
  local device="${VAAPI_DRM_DEVICE:-/dev/dri/renderD128}"
  if [[ -e "$device" ]]; then
    vainfo --display drm --device "$device" 2>&1
  else
    vainfo 2>&1
  fi
}

multimedia_vaapi_profiles_complete() {
  local report="$1"
  grep -q 'VAProfileH264' <<<"$report" &&
    grep -q 'VAProfileHEVC' <<<"$report" &&
    grep -q 'VAProfileAV1' <<<"$report" &&
    grep -q 'VAProfileVP9' <<<"$report"
}

multimedia_install_full_ffmpeg() {
  if rpm -q ffmpeg >/dev/null 2>&1; then
    log_info GNOME 'RPM Fusion ffmpeg already installed'
    return 0
  fi

  if rpm -q ffmpeg-free >/dev/null 2>&1; then
    run_mutating GNOME sudo dnf -y swap ffmpeg-free ffmpeg --allowerasing
  else
    run_mutating GNOME sudo dnf -y install ffmpeg
  fi
}

multimedia_converge_intel_media_driver() {
  local policy="${INTEL_MEDIA_DRIVER_POLICY:-auto}" report=""
  case "$policy" in
    auto|fedora-free|rpmfusion-full) ;;
    *) log_error GNOME "invalid INTEL_MEDIA_DRIVER_POLICY=$policy"; return "$EXIT_CONFIG_FAILED" ;;
  esac

  multimedia_arc_b580_present || return 0
  [[ "$policy" != fedora-free ]] || { log_info GNOME 'Intel media policy keeps Fedora free driver'; return 0; }
  is_true "${ENABLE_RPMFUSION:-true}" || { log_warn GNOME 'RPM Fusion disabled; cannot use full Intel media driver'; return 0; }

  if [[ "$policy" == auto ]]; then
    if ! command_exists vainfo; then
      log_warn GNOME 'vainfo unavailable; preserving Fedora Intel media driver instead of guessing'
      return 0
    fi
    report="$(multimedia_vainfo || true)"
    if [[ -n "$report" ]] && multimedia_vaapi_profiles_complete "$report"; then
      log_info GNOME 'Fedora Intel media driver already exposes H264/HEVC/AV1/VP9; no swap needed'
      return 0
    fi
    if [[ -z "$report" ]]; then
      log_warn GNOME 'VA-API probe unavailable; preserving Fedora Intel media driver instead of guessing'
      return 0
    fi
    log_info GNOME 'VA-API profile gap detected on Arc B580; selecting RPM Fusion intel-media-driver'
  fi

  if rpm -q intel-media-driver >/dev/null 2>&1; then
    return 0
  fi
  if rpm -q libva-intel-media-driver >/dev/null 2>&1; then
    run_mutating GNOME sudo dnf -y swap libva-intel-media-driver intel-media-driver --allowerasing
  else
    run_mutating GNOME sudo dnf -y install intel-media-driver
  fi
}

gnome_multimedia_precheck() {
  command_exists dnf && command_exists rpm
}

gnome_multimedia_plan() {
  echo 'Install Fedora GStreamer + OpenH264 + Intel oneVPL, switch ffmpeg-free to full RPM Fusion ffmpeg, add freeworld codecs/thumbnails, and converge Intel Arc VA-API only when the measured profile set requires it.'
}

gnome_multimedia_apply() {
  install_manifest_packages GNOME "$REPO_ROOT/manifests/packages-multimedia-fedora.txt"
  is_true "${ENABLE_RPMFUSION:-true}" || return 0
  multimedia_install_full_ffmpeg
  install_manifest_packages GNOME "$REPO_ROOT/manifests/packages-rpmfusion.txt"
  multimedia_converge_intel_media_driver
}

gnome_multimedia_postcheck() {
  is_true "${DRY_RUN:-true}" && return 0
  rpm -q gstreamer1-plugins-base gstreamer1-plugins-good gstreamer1-plugins-bad-free gstreamer1-plugin-openh264 libvpl intel-vpl-gpu-rt >/dev/null || return "$EXIT_POSTCHECK_FAILED"

  is_true "${ENABLE_RPMFUSION:-true}" || return 0
  rpm -q ffmpeg ffmpegthumbnailer gstreamer1-plugins-bad-freeworld gstreamer1-plugins-ugly gstreamer1-plugin-libav >/dev/null || return "$EXIT_POSTCHECK_FAILED"
  rpm -q ffmpeg-free >/dev/null 2>&1 && { log_error GNOME 'ffmpeg-free still installed after full FFmpeg convergence'; return "$EXIT_POSTCHECK_FAILED"; }

  if multimedia_arc_b580_present && command_exists vainfo; then
    local report
    report="$(multimedia_vainfo || true)"
    if [[ -n "$report" ]] && ! multimedia_vaapi_profiles_complete "$report"; then
      log_warn GNOME 'Arc B580 VA-API probe does not expose the complete H264/HEVC/AV1/VP9 profile set; run media-doctor'
      [[ "${INTEL_MEDIA_DRIVER_POLICY:-auto}" == fedora-free ]] || return "$EXIT_POSTCHECK_FAILED"
    fi
  fi
}

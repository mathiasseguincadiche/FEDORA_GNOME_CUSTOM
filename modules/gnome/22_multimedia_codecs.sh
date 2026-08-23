#!/usr/bin/env bash
set -Eeuo pipefail
gnome_multimedia_precheck() { command_exists dnf; }
gnome_multimedia_plan() { echo 'If RPM Fusion is enabled, install FFmpeg/GStreamer codecs and ffmpegthumbnailer for a complete desktop media/preview experience.'; }
gnome_multimedia_apply() { is_true "${ENABLE_RPMFUSION:-true}" || return 0; install_manifest_packages GNOME "$REPO_ROOT/manifests/packages-rpmfusion.txt"; }
gnome_multimedia_postcheck() { is_true "${DRY_RUN:-true}" && return 0; is_true "${ENABLE_RPMFUSION:-true}" || return 0; command_exists ffmpeg && command_exists ffmpegthumbnailer; }

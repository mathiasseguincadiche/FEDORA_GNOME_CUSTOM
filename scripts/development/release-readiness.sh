#!/usr/bin/env bash
# Read-only readiness check before moving the Golden profile to the next Fedora
# release (default: Fedora 45 / GNOME Shell 51). Nothing is installed or changed.
#
# It answers one question per pinned third-party component:
#   "does a build exist for the target release, and what exact pin would we use?"
#
# Usage: release-readiness.sh [--fedora N] [--shell N] [--pin] [--report-only]
#   --pin          download candidate extension zips and print SHA-256 config lines
#   --report-only  always exit 0 (used by the weekly CI report)
set -Eeuo pipefail

target_fedora=45
target_shell=51
pin=false
report_only=false
while (($#)); do
  case "$1" in
    --fedora) target_fedora="${2:?}"; shift 2 ;;
    --shell) target_shell="${2:?}"; shift 2 ;;
    --pin) pin=true; shift ;;
    --report-only) report_only=true; shift ;;
    *) echo "Usage: $0 [--fedora N] [--shell N] [--pin] [--report-only]" >&2; exit 2 ;;
  esac
done
[[ "$target_fedora" =~ ^[0-9]+$ && "$target_shell" =~ ^[0-9]+$ ]] || { echo 'Versions must be numbers' >&2; exit 2; }

for cmd in curl python3; do command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 1; }; done

EGO="${RELEASE_READINESS_EGO_URL:-https://extensions.gnome.org}"
COPR="${RELEASE_READINESS_COPR_URL:-https://copr.fedorainfracloud.org}"
GH_API="${RELEASE_READINESS_GITHUB_API:-https://api.github.com}"
ready=0; blocked=0

report() {
  local state="$1" component="$2" detail="$3"
  printf '%-8s %-26s %s\n' "$state" "$component" "$detail"
  # Plain assignments: ((x+=1)) / ((x-=1)) return 1 when the result is 0,
  # which aborts the script under `set -e`.
  case "$state" in READY) ready=$((ready + 1)) ;; SKIPPED) ;; *) blocked=$((blocked + 1)) ;; esac
}

fetch() { curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 --max-time 30 "$@"; }

# GNOME Shell extensions pinned from extensions.gnome.org -------------------
check_ego_extension() {
  local label="$1" uuid="$2" key="$3" json info version tag
  if ! json="$(fetch "$EGO/extension-info/?uuid=$uuid&shell_version=$target_shell" 2>/dev/null)"; then
    report BLOCKED "$label" "no release published for GNOME Shell $target_shell yet"
    return 0
  fi
  info="$(python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print(d.get("version",""), d.get("version_tag",""))' <<<"$json")" || info=''
  read -r version tag <<<"$info"
  if [[ -z "${version:-}" || -z "${tag:-}" ]]; then
    report BLOCKED "$label" "unexpected extensions.gnome.org answer"
    return 0
  fi
  report READY "$label" "site version $version, review $tag"
  if $pin; then
    local zip sha url="$EGO/review/download/$tag.shell-extension.zip"
    zip="$(mktemp --suffix=.zip)"
    if fetch "$url" --output "$zip" 2>/dev/null; then
      sha="$(sha256sum "$zip" | awk '{print $1}')"
      printf '         %s_SOURCE_URL="%s"\n         %s_REVIEW_ID="%s"\n         %s_VERSION="%s"\n         %s_SHELL_VERSION="%s"\n         %s_SHA256="%s"\n' \
        "$key" "$url" "$key" "$tag" "$key" "$version" "$key" "$target_shell" "$key" "$sha"
    else
      printf '         (download failed: %s)\n' "$url"
    fi
    rm -f "$zip"
  fi
}

# Tiling Assistant is pinned from its GitHub release ------------------------
check_tiling_assistant() {
  local json asset tag zip meta
  if ! json="$(fetch "$GH_API/repos/Leleat/Tiling-Assistant/releases/latest" 2>/dev/null)"; then
    report BLOCKED 'Tiling Assistant' 'GitHub release metadata unavailable'
    return 0
  fi
  tag=''; asset=''
  read -r tag asset < <(python3 -c '
import json,sys
d=json.loads(sys.stdin.read())
url=next((a["browser_download_url"] for a in d.get("assets",[]) if a["name"].endswith(".shell-extension.zip")),"")
print(d.get("tag_name",""), url)' <<<"$json" || true) || true
  [[ -n "${asset:-}" ]] || { report BLOCKED 'Tiling Assistant' "no extension zip in release ${tag:-?}"; return 0; }
  zip="$(mktemp --suffix=.zip)"; meta=''
  if fetch "$asset" --output "$zip" 2>/dev/null; then
    meta="$(python3 -c 'import json,sys,zipfile; print(" ".join(json.load(zipfile.ZipFile(sys.argv[1]).open("metadata.json"))["shell-version"]))' "$zip" 2>/dev/null || true)"
  fi
  if [[ " $meta " == *" $target_shell "* ]]; then
    report READY 'Tiling Assistant' "$tag declares GNOME Shell $target_shell"
    $pin && printf '         TILING_ASSISTANT_SOURCE_URL="%s"\n         TILING_ASSISTANT_SHA256="%s"\n' "$asset" "$(sha256sum "$zip" | awk '{print $1}')"
  else
    report BLOCKED 'Tiling Assistant' "$tag declares shells: ${meta:-unknown}"
  fi
  rm -f "$zip"
}

# Kernel COPRs --------------------------------------------------------------
check_copr() {
  local label="$1" owner="$2" project="$3" json
  if ! json="$(fetch "$COPR/api_3/project?ownername=$owner&projectname=$project" 2>/dev/null)"; then
    report BLOCKED "$label" 'COPR metadata unavailable'
    return 0
  fi
  if python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); sys.exit(0 if sys.argv[1] in d.get("chroot_repos",{}) else 1)' "fedora-$target_fedora-x86_64" <<<"$json"; then
    report READY "$label" "chroot fedora-$target_fedora-x86_64 enabled"
  else
    report BLOCKED "$label" "no fedora-$target_fedora-x86_64 chroot yet"
  fi
}

# Fedora-packaged extensions (only meaningful on a Fedora host) ------------
check_fedora_package() {
  local label="$1" package="$2" found
  if ! command -v dnf5 >/dev/null 2>&1; then
    report SKIPPED "$label" 'dnf5 unavailable (run on the Fedora host)'
    return 0
  fi
  found="$(dnf5 -q --releasever="$target_fedora" repoquery --latest-limit 1 --qf '%{VERSION}-%{RELEASE}\n' "$package" 2>/dev/null | head -n1 || true)"
  if [[ -n "$found" ]]; then report READY "$label" "$package $found in Fedora $target_fedora"
  else report BLOCKED "$label" "$package not resolvable for Fedora $target_fedora"; fi
}

printf 'Golden release readiness — target Fedora %s / GNOME Shell %s\n\n' "$target_fedora" "$target_shell"
check_copr 'kernel-cachyos COPR' bieszczaders kernel-cachyos
check_copr 'kernel-vanilla COPR' '@kernel-vanilla' stable
check_ego_extension 'Desktop Icons NG' 'ding@rastersoft.com' DING
check_ego_extension 'Show Desktop Plus' 'show-desktop-plus@attentivecoder' SHOW_DESKTOP_PLUS
check_ego_extension 'Resource Monitor' 'Resource_Monitor@Ory0n' RESOURCE_MONITOR
check_tiling_assistant
check_fedora_package 'Dash to Dock (RPM)' gnome-shell-extension-dash-to-dock
check_fedora_package 'AppIndicator (RPM)' gnome-shell-extension-appindicator
check_fedora_package 'adw-gtk3 (RPM)' adw-gtk3-theme

printf '\nREADY=%s BLOCKED=%s\n' "$ready" "$blocked"
printf 'Next steps are described in %s\n' "docs/UPGRADE_FEDORA_45.md"
if $report_only || ((blocked == 0)); then exit 0; fi
exit 1

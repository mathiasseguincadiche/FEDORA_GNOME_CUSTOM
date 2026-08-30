#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_MANIFEST="$ROOT/manifests/packages-applications-gtk4.txt"
CORE_MANIFEST="$ROOT/manifests/packages-gnome.txt"

grep -Fq 'GTK4_NATIVE_APPS_ONLY="true"' "$ROOT/config/applications.conf"
grep -Fq 'TERMINAL_PACKAGE="ptyxis"' "$ROOT/config/applications.conf"
grep -Fxq 'ptyxis' "$APP_MANIFEST"
grep -Fq 'applications.gtk4|APPLICATIONS|desktop.shell_ux' "$ROOT/manifests/module-plan.conf"
grep -Fq 'kvm.preflight|KVM|applications.validation' "$ROOT/manifests/module-plan.conf"
grep -Fq 'backup.preflight|BACKUP|kvm.validation' "$ROOT/manifests/module-plan.conf"

mapfile -t apps < <(grep -Ev '^[[:space:]]*(#|$)' "$APP_MANIFEST")
((${#apps[@]} > 0)) || { echo 'GTK4 application manifest is empty' >&2; exit 1; }

if printf '%s\n' "${apps[@]}" | sort | uniq -d | grep -q .; then
  echo 'duplicate application package found' >&2
  exit 1
fi

if comm -12 \
  <(grep -Ev '^[[:space:]]*(#|$)' "$CORE_MANIFEST" | sort -u) \
  <(printf '%s\n' "${apps[@]}" | sort -u) | grep -q .; then
  echo 'GNOME core and GTK4 application manifests must not overlap' >&2
  exit 1
fi

echo 'GTK4 applications policy: PASS'

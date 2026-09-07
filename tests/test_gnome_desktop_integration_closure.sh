#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail(){ echo "GNOME desktop integration closure: $*" >&2; exit 1; }

grep -Fxq localsearch "$ROOT/manifests/packages-nautilus.txt" || fail 'localsearch must be an explicit Nautilus dependency'
grep -Fxq xdg-user-dirs-gtk "$ROOT/manifests/packages-gnome.txt" || fail 'xdg-user-dirs-gtk must be explicit'

for file in \
  diagnostics/gnome-runtime-doctor diagnostics/localsearch-doctor diagnostics/nautilus-ptyxis-doctor \
  diagnostics/ptyxis-integration-doctor diagnostics/default-apps-doctor diagnostics/portal-functional-doctor \
  diagnostics/nautilus-vm-live-doctor diagnostics/gnome-desktop-integration-doctor \
  scripts/gnome/configure-default-apps.sh scripts/validation/gnome-ux-matrix.sh; do
  [[ -f "$ROOT/$file" ]] || fail "missing $file"
  bash -n "$ROOT/$file"
done

for token in DEFAULT_FILE_MANAGER_DESKTOP DEFAULT_PDF_DESKTOP DEFAULT_IMAGE_DESKTOP DEFAULT_TEXT_DESKTOP DEFAULT_VIDEO_DESKTOP DEFAULT_ARCHIVE_DESKTOP DEFAULT_BROWSER_DESKTOP LOCALSEARCH_CANARY_WAIT_SECONDS; do
  grep -Fq "$token" "$ROOT/config/gnome.conf" || fail "missing config $token"
done

for token in 'gnome-terminal-nautilus' 'localsearch-doctor'; do grep -Fq "$token" "$ROOT/modules/gnome/21_nautilus_integration.sh" || fail "Nautilus module missing $token"; done
for token in 'nautilus-ptyxis-doctor' 'ptyxis-integration-doctor' 'default-apps-doctor' 'configure-default-apps.sh'; do grep -Fq "$token" "$ROOT/modules/applications/49_applications_validation.sh" || fail "application validation missing $token"; done
for token in 'org.gnome.Ptyxis' '--working-directory' 'gnome-terminal-nautilus'; do grep -Fq -- "$token" "$ROOT/diagnostics/nautilus-ptyxis-doctor" || fail "Nautilus/Ptyxis doctor missing $token"; done
for token in '--working-directory' '--standalone' 'FGC_PTYXIS_MARKER'; do grep -Fq -- "$token" "$ROOT/diagnostics/ptyxis-integration-doctor" || fail "Ptyxis functional doctor missing $token"; done
for token in 'localsearch status' 'localsearch index' 'localsearch search --files' 'info --eligible'; do grep -Fq -- "$token" "$ROOT/diagnostics/localsearch-doctor" || fail "LocalSearch doctor missing $token"; done

for token in FileChooser OpenURI Notification ScreenCast CreateSession JE_CONFIRME_FILECHOOSER JE_CONFIRME_SCREENCAST; do grep -Fq "$token" "$ROOT/diagnostics/portal-functional-doctor" || fail "portal smoke missing $token"; done
for token in 'sftp://' 'smb://' 'gio list' 'gio copy' 'gio cat' 'gio remove' 'physical_runtime_write_evidence nautilus-vm-live'; do grep -Fq "$token" "$ROOT/diagnostics/nautilus-vm-live-doctor" || fail "VM live smoke missing $token"; done

for token in 'gnome-desktop-integration-doctor' 'gnome-ux-matrix.sh' 'portal_functional=PASS' 'localsearch=PASS' 'nautilus_ptyxis=PASS' 'ptyxis-doctor'; do grep -Fq "$token" "$ROOT/scripts/validation/gate2-virtualbox.sh" || fail "Gate 2 missing $token"; done
for token in 'FINAL_CERT_MIN_SUSPEND_CYCLES' 'portal-functional-doctor' 'nautilus-vm-live-doctor' 'workstation_fingerprint=' 'Open in Console'; do grep -Fq "$token" "$ROOT/scripts/validation/gnome-ux-matrix.sh" || fail "UX matrix missing $token"; done

grep -Fq 'gnome-desktop-integration-doctor' "$ROOT/diagnostics/application-runtime-doctor" || fail 'runtime drift must include GNOME desktop integration'
grep -Fq 'GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md' "$ROOT/docs/README.md" || fail 'documentation index missing GNOME desktop certification runbook'

echo 'GNOME desktop integration closure: PASS'

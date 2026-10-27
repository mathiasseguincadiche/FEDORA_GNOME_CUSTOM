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
for token in 'sftp://' 'gio list' 'gio copy' 'gio cat' 'gio remove' 'physical_runtime_write_evidence nautilus-vm-live'; do grep -Fq "$token" "$ROOT/diagnostics/nautilus-vm-live-doctor" || fail "VM live smoke missing $token"; done

for token in 'FINAL_CERT_MIN_SUSPEND_CYCLES' 'portal-functional-doctor' 'nautilus-vm-live-doctor' 'workstation_fingerprint=' 'Open in Console'; do grep -Fq "$token" "$ROOT/scripts/validation/gnome-ux-matrix.sh" || fail "UX matrix missing $token"; done

grep -Fq 'gnome-desktop-integration-doctor' "$ROOT/diagnostics/application-runtime-doctor" || fail 'runtime drift must include GNOME desktop integration'
grep -Fq 'GNOME_DESKTOP_INTEGRATION_CERTIFICATION.md' "$ROOT/docs/README.md" || fail 'documentation index missing GNOME desktop certification runbook'

python3 -B - "$ROOT" <<'PY'
from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])
with tempfile.TemporaryDirectory(prefix='fgc-default-apps-') as directory:
    fixture = Path(directory)
    for path in ('lib', 'diagnostics', 'scripts/gnome', 'bin', 'mime', 'data/applications'):
        (fixture / path).mkdir(parents=True)
    for path in ('diagnostics/default-apps-doctor', 'scripts/gnome/configure-default-apps.sh'):
        shutil.copyfile(root / path, fixture / path)
    (fixture / 'lib/bootstrap.sh').write_text(
        f'source "{root}/lib/constants.sh"\nengine_bootstrap() {{ :; }}\n'
        'ui_error() { echo "$*" >&2; }\nui_meta() { :; }\n')
    applications = ('org.gnome.Nautilus', 'org.gnome.Papers', 'org.gnome.Loupe',
                    'org.gnome.TextEditor', 'org.gnome.Showtime', 'org.gnome.FileRoller',
                    'brave-browser')
    for app in applications:
        (fixture / 'data/applications' / (app + '.desktop')).touch()
    (fixture / 'bin/xdg-mime').write_text('''#!/usr/bin/env python3
import os
from pathlib import Path
import sys
args = sys.argv[1:]
path = Path(os.environ['MIME_FIXTURE']) / args[2].replace('/', '_')
if args[0] == 'default':
    path.write_text(args[1])
elif args[:2] == ['query', 'default']:
    print(path.read_text() if path.exists() else '')
else:
    sys.exit(99)
''')
    (fixture / 'bin/update-desktop-database').write_text('#!/bin/sh\nexit 0\n')
    for path in (fixture / 'bin').iterdir():
        path.chmod(0o755)
    env = dict(os.environ, PATH=str(fixture / 'bin') + ':' + os.environ['PATH'],
               HOME=str(fixture), XDG_DATA_HOME=str(fixture / 'data'),
               MIME_FIXTURE=str(fixture / 'mime'))

    def run(path, *args, expected=0):
        result = subprocess.run(['bash', str(fixture / path), *args], env=env,
                                text=True, capture_output=True, timeout=10)
        assert result.returncode == expected, result.stderr + result.stdout

    configure = 'scripts/gnome/configure-default-apps.sh'
    doctor = 'diagnostics/default-apps-doctor'
    run(configure, 'native')
    run(doctor, '--quiet', '--native')
    assert not (fixture / 'mime/text_html').exists(), 'native mode forced the vendor browser'
    run(doctor, '--quiet', '--full', expected=1)
    (fixture / 'mime/application_pdf').write_text('wrong.desktop')
    run(doctor, '--quiet', '--native', expected=1)
    run(configure, 'full')
    run(doctor, '--quiet', '--full')
    run(configure, 'gate2', expected=2)
    run(doctor, '--gate2', expected=2)
print('Default application modes: PASS (native/full, drift refused, retired gate2 rejected)')
PY

echo 'GNOME desktop integration closure: PASS'

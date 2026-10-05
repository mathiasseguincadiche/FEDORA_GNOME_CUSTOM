#!/usr/bin/env bash
# Disposable guest test; independent LibreOffice profile avoids a user's session.
set -Eeuo pipefail
[[ "${GITHUB_ACTIONS:-}" == true || -e /etc/fgc-ci-lab ]] || exit 50
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
marker="FGC-document-roundtrip-$(date +%s)"
printf '%s\n' "$marker" > "$work/input.txt"
libreoffice "-env:UserInstallation=file://$work/profile" --headless \
  --convert-to odt --outdir "$work" "$work/input.txt"
[[ -s "$work/input.odt" ]]
unzip -p "$work/input.odt" content.xml | grep -Fq "$marker"
libreoffice "-env:UserInstallation=file://$work/profile" --headless \
  --convert-to pdf --outdir "$work" "$work/input.odt"
[[ -s "$work/input.pdf" ]]
pdftotext "$work/input.pdf" "$work/output.txt"
grep -Fxq "$marker" "$work/output.txt"
echo 'PASS: actual LibreOffice TXT -> ODT -> PDF text roundtrip'

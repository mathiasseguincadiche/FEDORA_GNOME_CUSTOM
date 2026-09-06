#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/application_runtime.sh
source "$ROOT/lib/application_runtime.sh"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export REPO_ROOT="$tmp/repo" HOME="$tmp/home" XDG_DATA_HOME="$tmp/home/.local/share"
export APPLICATION_RUNTIME_REPO_ROOT="$tmp/etc/yum.repos.d"
export UNVERIFIED_FLATHUB_ALLOWLIST='com.slack.Slack'
mkdir -p "$REPO_ROOT/manifests" "$REPO_ROOT/config/repos" "$APPLICATION_RUNTIME_REPO_ROOT" "$tmp/bin" \
  "$XDG_DATA_HOME/flatpak/exports/share/applications"
cat > "$REPO_ROOT/manifests/application-runtime-contract.tsv" <<'EOF'
vendor-rpm	code	code	--version	signed-vendor
flatpak	com.slack.Slack	-	-	community-unverified
EOF
cat > "$REPO_ROOT/manifests/application-provenance.tsv" <<'EOF'
code	vendor-rpm	signed-vendor	Microsoft signed repository
com.slack.Slack	flatpak	community-unverified	Reviewed community exception
EOF
printf '[code]\ngpgcheck=1\n' > "$REPO_ROOT/config/repos/vscode.repo"
cp "$REPO_ROOT/config/repos/vscode.repo" "$APPLICATION_RUNTIME_REPO_ROOT/vscode.repo"
cat > "$XDG_DATA_HOME/flatpak/exports/share/applications/com.slack.Slack.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Slack
Exec=flatpak run com.slack.Slack
EOF

cat > "$tmp/bin/rpm" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == -q ]] && exit 0
exit 1
EOF
cat > "$tmp/bin/code" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == --version ]]
EOF
cat > "$tmp/bin/desktop-file-validate" <<'EOF'
#!/usr/bin/env bash
[[ -r "$1" ]]
EOF
cat > "$tmp/bin/flatpak" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  info)
    case "${2:-}" in
      --show-origin) printf '%s\n' "${FAKE_ORIGIN:-flathub}" ;;
      --show-runtime) printf '%s\n' 'org.freedesktop.Platform/x86_64/25.08' ;;
      *) exit 0 ;;
    esac
    ;;
  run) [[ "${BAD_FLATPAK_RUN:-false}" != true ]] ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp/bin"/*
PATH="$tmp/bin:$PATH"
export PATH

application_runtime_validate_contract
if FAKE_ORIGIN=other application_runtime_validate_contract; then echo 'non-Flathub origin was accepted' >&2; exit 1; fi
printf '# drift\n' >> "$APPLICATION_RUNTIME_REPO_ROOT/vscode.repo"
if application_runtime_validate_contract; then echo 'modified vendor repository file was accepted' >&2; exit 1; fi
cp "$REPO_ROOT/config/repos/vscode.repo" "$APPLICATION_RUNTIME_REPO_ROOT/vscode.repo"
UNVERIFIED_FLATHUB_ALLOWLIST=''
if UNVERIFIED_FLATHUB_ALLOWLIST='' application_runtime_validate_contract; then echo 'unreviewed community Flatpak was accepted' >&2; exit 1; fi
if BAD_FLATPAK_RUN=true application_runtime_validate_contract; then echo 'Flatpak runtime startup failure was accepted' >&2; exit 1; fi

echo 'application runtime behavior: PASS'

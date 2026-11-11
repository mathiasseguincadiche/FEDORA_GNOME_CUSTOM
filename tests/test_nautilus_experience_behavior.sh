#!/usr/bin/env bash
# Test the optional Nautilus experience helper with isolated fake GIO, no GNOME needed.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/repo/diagnostics" "$tmp/repo/lib" "$tmp/bin" "$tmp/home" "$tmp/reports"
cp "$ROOT/diagnostics/nautilus-experience-doctor" "$tmp/repo/diagnostics/"
cat > "$tmp/repo/lib/bootstrap.sh" <<'BOOT'
engine_bootstrap() {
  REPORT_ROOT="$TEST_REPORT_ROOT"
  RUN_ID=test-run
  EXIT_USAGE=2
  EXIT_PRECHECK_FAILED=20
  EXIT_POSTCHECK_FAILED=40
}
ui_check() { printf '%s %s %s\n' "$1" "$2" "$3"; }
BOOT
cat > "$tmp/bin/gio" <<'GIO'
#!/usr/bin/env bash
case "$1" in
  info) [[ -f "$2" ]] ;;
  copy) [[ -z "${TEST_FAIL_COPY:-}" ]] && cp -- "$2" "$3" ;;
  cat) cat -- "$2" ;;
  remove) rm -- "$2" ;;
  *) exit 2 ;;
esac
GIO
chmod +x "$tmp/bin/gio"
export HOME="$tmp/home" PATH="$tmp/bin:$PATH" TEST_REPORT_ROOT="$tmp/reports"
doctor="$tmp/repo/diagnostics/nautilus-experience-doctor"

bash "$doctor" --local > "$tmp/output"
grep -Fq 'PASS (isolated canary)' "$tmp/output"
grep -Fxq 'status=PASS' "$tmp/reports/nautilus-experience-test-run.txt"
[[ -z "$(find "$HOME" -maxdepth 1 -name '.fgc-nautilus-io.*' -print -quit)" ]]

rc=0; TEST_FAIL_COPY=true bash "$doctor" --local > "$tmp/output" || rc=$?
[[ "$rc" == 40 ]] && grep -Fq 'local canary failed' "$tmp/output"
grep -Fxq 'status=FAIL' "$tmp/reports/nautilus-experience-test-run.txt"
[[ -z "$(find "$HOME" -maxdepth 1 -name '.fgc-nautilus-io.*' -print -quit)" ]]

rc=0; XDG_CURRENT_DESKTOP=GNOME bash "$doctor" --manual </dev/null > "$tmp/output" || rc=$?
[[ "$rc" == 20 ]] && grep -Fq 'interactive GNOME terminal' "$tmp/output"
[[ ! -e "$HOME/.local/share/nautilus" ]]
echo 'nautilus experience behavior: PASS'

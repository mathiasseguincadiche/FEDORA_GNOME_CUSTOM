#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
helper="$ROOT/.github/scripts/resolve-release-tag-commit.sh"
[[ -x "$helper" || -r "$helper" ]]

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
case "${MOCK_GH_MODE:-}:$*" in
  absent:*)
    echo 'gh: Not Found (HTTP 404)' >&2
    exit 1
    ;;
  lightweight:*git/ref/tags/*)
    printf '%s\n' '{"object":{"type":"commit","sha":"1111111111111111111111111111111111111111"}}'
    ;;
  annotated:*git/ref/tags/*)
    printf '%s\n' '{"object":{"type":"tag","sha":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}'
    ;;
  annotated:*git/tags/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa*)
    printf '%s\n' '{"object":{"type":"commit","sha":"2222222222222222222222222222222222222222"}}'
    ;;
  malformed:*git/ref/tags/*)
    printf '%s\n' '{"object":{"type":"commit","sha":null}}'
    ;;
  api500:*)
    echo 'gh: Internal Server Error (HTTP 500)' >&2
    exit 1
    ;;
  *)
    echo "unexpected mock gh request: $*" >&2
    exit 90
    ;;
esac
SH
chmod +x "$tmp/bin/gh"

run_helper() {
  local mode="$1"
  shift
  PATH="$tmp/bin:$PATH" MOCK_GH_MODE="$mode" GITHUB_REPOSITORY='owner/repo' "$helper" 'v0.14.0-rc.1' "$@"
}

rc=0
out="$(run_helper absent 2>"$tmp/absent.err")" || rc=$?
[[ "$rc" -eq 3 ]]
[[ -z "$out" ]]
[[ ! -s "$tmp/absent.err" || "$(<"$tmp/absent.err")" != *null* ]]

[[ "$(run_helper lightweight)" == '1111111111111111111111111111111111111111' ]]
[[ "$(run_helper annotated)" == '2222222222222222222222222222222222222222' ]]

rc=0
out="$(run_helper malformed 2>"$tmp/malformed.err")" || rc=$?
[[ "$rc" -eq 65 ]]
[[ "$out" != null ]]

after_500="$tmp/api500.err"
rc=0
run_helper api500 >/dev/null 2>"$after_500" || rc=$?
[[ "$rc" -ne 0 && "$rc" -ne 3 ]]
grep -Fq 'HTTP 500' "$after_500"

grep -Fq '.github/scripts/resolve-release-tag-commit.sh' "$ROOT/.github/workflows/release.yml"
if grep -Fq 'resolve_tag_commit || true' "$ROOT/.github/workflows/release.yml"; then
  echo 'release workflow still swallows tag-resolution failures' >&2
  exit 1
fi

echo 'release workflow contract: PASS'

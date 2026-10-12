#!/usr/bin/env bash
# CI contract: verified official CDN, bounded retries, no fake-success on failure.
# All flatpak calls are mocked: no network traffic or system repo mutations.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat > "$tmp/bin/flatpak" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "${1:-}" == remote-add ]]; then
  [[ " $* " == *' https://dl.flathub.org/repo/flathub.flatpakrepo '* ]] || exit 99
  printf 'attempt\n' >> "${CI_TEST_STATE:?}"
  count="$(wc -l < "${CI_TEST_STATE:?}")"
  ((count >= ${CI_TEST_SUCCEED_AFTER:-99})) || exit 7
elif [[ "${1:-}" == remotes ]]; then
  printf 'flathub\n'
else
  exit 98
fi
MOCK
cat > "$tmp/bin/sleep" <<'MOCK'
#!/usr/bin/env bash
exit 0
MOCK
chmod +x "$tmp/bin/flatpak" "$tmp/bin/sleep"
export PATH="$tmp/bin:$PATH" CI_TEST_STATE="$tmp/attempts"
touch "$CI_TEST_STATE"
if CI_TEST_SUCCEED_AFTER=5 bash "$ROOT/scripts/ci/ensure-flathub.sh" >"$tmp/failure.log" 2>&1; then
  echo 'Flathub bootstrap incorrectly succeeded after four failures' >&2; exit 1
fi
[[ "$(wc -l < "$CI_TEST_STATE")" -eq 4 ]]
grep -Fq 'fails closed' "$tmp/failure.log" || {
  echo 'exhausted retry diagnostic missing' >&2; exit 1;
}
: > "$CI_TEST_STATE"
CI_TEST_SUCCEED_AFTER=3 bash "$ROOT/scripts/ci/ensure-flathub.sh" >"$tmp/success.log" 2>&1
[[ "$(wc -l < "$CI_TEST_STATE")" -eq 3 ]]
grep -Fq 'attempt 3' "$tmp/success.log"
: > "$CI_TEST_STATE"
if bash "$ROOT/scripts/ci/ensure-flathub.sh" --unsafe >"$tmp/argument.log" 2>&1; then
  echo 'Flathub bootstrap accepted unexpected argument' >&2; exit 1
fi
[[ ! -s "$CI_TEST_STATE" ]]
printf '%s\n' 'Strict Flathub retry/bootstrap fixtures: PASS'

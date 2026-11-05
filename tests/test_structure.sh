#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
while IFS='|' read -r id scope _deps path; do
  [[ -z "$id" || "$id" == \#* ]] && continue
  [[ -n "$scope" && -r "$ROOT/$path" ]] || { echo "invalid module entry: $id $path" >&2; exit 1; }
done < "$ROOT/manifests/module-plan.conf"
while IFS= read -r file; do bash -n "$ROOT/$file"; done < <(git -C "$ROOT" ls-files '*.sh')
# Every entrypoint, doctor, script and library states its role in a comment right after
# the shebang (CONTRIBUTING.md, "Shell"). Modules describe themselves through their plan.
missing=()
while IFS= read -r file; do
  [[ "$(head -c 2 "$ROOT/$file")" == '#!' ]] || continue
  [[ "$file" == *.py ]] && continue
  sed -n '2,5p' "$ROOT/$file" | grep -E '^#( |$)' | grep -vq shellcheck || missing+=("$file")
done < <(git -C "$ROOT" ls-files 'diagnostics/*' 'scripts/*.sh' 'lib/*.sh' 'installer/*.sh' '.github/scripts/*.sh' ':(top,glob)*.sh')
((${#missing[@]} == 0)) || { printf 'file without a role header: %s\n' "${missing[@]}" >&2; exit 1; }
echo 'structure: PASS'

#!/usr/bin/env bash
set -Eeuo pipefail

tag="${1:-}"
repo="${GITHUB_REPOSITORY:-}"
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+-rc\.[0-9]+$ ]] || {
  echo "Invalid release tag: $tag" >&2
  exit 2
}
[[ "$repo" =~ ^[^/]+/[^/]+$ ]] || {
  echo 'GITHUB_REPOSITORY must be owner/name.' >&2
  exit 2
}
command -v gh >/dev/null 2>&1 || { echo 'gh is required.' >&2; exit 127; }
command -v jq >/dev/null 2>&1 || { echo 'jq is required.' >&2; exit 127; }

err="$(mktemp)"
trap 'rm -f "$err"' EXIT

if ref_json="$(gh api "repos/${repo}/git/ref/tags/${tag}" 2>"$err")"; then
  :
else
  rc=$?
  if grep -Eq 'Not Found|HTTP[[:space:]]+404|\(HTTP 404\)' "$err"; then
    exit 3
  fi
  cat "$err" >&2
  exit "$rc"
fi

object_type="$(jq -er '.object.type | select(type == "string" and length > 0)' <<<"$ref_json")" || {
  echo "Malformed tag ref for $tag: missing object.type" >&2
  exit 65
}
object_sha="$(jq -er '.object.sha | select(type == "string" and length > 0)' <<<"$ref_json")" || {
  echo "Malformed tag ref for $tag: missing object.sha" >&2
  exit 65
}

depth=0
while [[ "$object_type" == tag ]]; do
  ((depth+=1))
  ((depth <= 8)) || { echo "Annotated-tag chain is unexpectedly deep for $tag" >&2; exit 65; }
  if tag_json="$(gh api "repos/${repo}/git/tags/${object_sha}")"; then
    :
  else
    exit $?
  fi
  object_type="$(jq -er '.object.type | select(type == "string" and length > 0)' <<<"$tag_json")" || exit 65
  object_sha="$(jq -er '.object.sha | select(type == "string" and length > 0)' <<<"$tag_json")" || exit 65
done

[[ "$object_type" == commit && "$object_sha" =~ ^[0-9a-f]{40}$ ]] || {
  echo "Tag $tag does not resolve to a commit." >&2
  exit 65
}
printf '%s\n' "$object_sha"

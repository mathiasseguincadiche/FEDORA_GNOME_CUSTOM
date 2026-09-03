#!/usr/bin/env bash
set -Eeuo pipefail

repo="${1:-mathiasseguincadiche/FEDORA_GNOME_CUSTOM}"
api="https://api.github.com/repos/${repo}"
command -v curl >/dev/null || { echo 'curl required' >&2; exit 2; }
command -v jq >/dev/null || { echo 'jq required' >&2; exit 2; }

repo_json="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$api")"
default_branch="$(jq -r '.default_branch' <<<"$repo_json")"
target_ref="refs/heads/$default_branch"
rulesets_json="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$api/rulesets")"

ruleset_id=''
while IFS= read -r candidate_id; do
  [[ -n "$candidate_id" ]] || continue
  detail="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$api/rulesets/$candidate_id")"
  if jq -e --arg ref "$target_ref" '
      .enforcement == "active" and
      (.target == "branch") and
      ((.conditions.ref_name.include // []) | any(. == $ref or . == "~DEFAULT_BRANCH"))
    ' <<<"$detail" >/dev/null; then
    ruleset_id="$candidate_id"
    ruleset_json="$detail"
    break
  fi
done < <(jq -r '.[] | select(.enforcement == "active" and .target == "branch") | .id' <<<"$rulesets_json")

if [[ -z "$ruleset_id" ]]; then
  echo "KO: no active branch ruleset explicitly targets $target_ref (or ~DEFAULT_BRANCH)." >&2
  exit 1
fi

required_rule() {
  local type="$1"
  jq -e --arg type "$type" '.rules | any(.type == $type)' <<<"$ruleset_json" >/dev/null || {
    echo "KO: ruleset $ruleset_id is missing rule: $type" >&2
    exit 1
  }
}

required_rule deletion
required_rule non_fast_forward
required_rule pull_request
required_rule required_status_checks

if ! jq -e '
    [.rules[] | select(.type == "pull_request") | .parameters.allowed_merge_methods] |
    any(. == ["merge"])
  ' <<<"$ruleset_json" >/dev/null; then
  echo "KO: ruleset $ruleset_id must allow merge commits only." >&2
  exit 1
fi

if ! jq -e '
    [.rules[] | select(.type == "required_status_checks") | .parameters.strict_required_status_checks_policy] |
    any(. == true)
  ' <<<"$ruleset_json" >/dev/null; then
  echo "KO: required status checks must require the branch to be up to date." >&2
  exit 1
fi

mapfile -t actual_checks < <(jq -r '.rules[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context' <<<"$ruleset_json" | sort -u)
required_checks=(contracts shellcheck guards packages packages-and-integration nautilus-ptyxis)
for check in "${required_checks[@]}"; do
  if ! printf '%s\n' "${actual_checks[@]}" | grep -Fxq "$check"; then
    echo "KO: required status check missing from ruleset $ruleset_id: $check" >&2
    exit 1
  fi
done

jq -e '.allow_merge_commit == true' <<<"$repo_json" >/dev/null || { echo 'KO: merge commits must be enabled.' >&2; exit 1; }
jq -e '.allow_squash_merge == false' <<<"$repo_json" >/dev/null || { echo 'KO: squash merge must be disabled.' >&2; exit 1; }
jq -e '.allow_rebase_merge == false' <<<"$repo_json" >/dev/null || { echo 'KO: rebase merge must be disabled.' >&2; exit 1; }
jq -e '.delete_branch_on_merge == true' <<<"$repo_json" >/dev/null || { echo 'KO: merged branches must be deleted automatically.' >&2; exit 1; }

printf 'OK: %s is protected by active ruleset %s with strict required checks and merge-only policy.\n' "$target_ref" "$ruleset_id"

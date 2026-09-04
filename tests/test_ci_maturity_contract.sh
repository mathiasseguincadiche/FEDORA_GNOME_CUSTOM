#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKOUT_SHA="11d5960a326750d5838078e36cf38b85af677262"
UPLOAD_ARTIFACT_SHA="ea165f8d65b6e75b540449e92b4886f43607fa02"

for file in .github/workflows/non-regression.yml .github/workflows/fedora-host-pretest.yml .github/workflows/fedora-package-preflight.yml .github/workflows/desktop-integration-pretest.yml .github/workflows/vm-pretest.yml .github/scripts/vm-pretest.sh docs/GITHUB_GOVERNANCE.md; do
  [[ -f "$ROOT/$file" ]] || { echo "missing CI maturity file: $file" >&2; exit 1; }
done

grep -Fq 'fedora:44' "$ROOT/.github/workflows/fedora-host-pretest.yml"
grep -Fq 'Install Fedora-native base contract' "$ROOT/.github/workflows/fedora-host-pretest.yml"
grep -Fq 'Validate multimedia provider convergence' "$ROOT/.github/workflows/fedora-host-pretest.yml"
grep -Fq 'ubuntu-26.04-server-cloudimg-amd64.img' "$ROOT/.github/scripts/vm-pretest.sh"
grep -Fq 'gpgv --keyring /usr/share/keyrings/ubuntu-cloudimage-keyring.gpg' "$ROOT/.github/scripts/vm-pretest.sh"
grep -Fq 'guest/ubuntu-devops/bootstrap-devops.sh' "$ROOT/.github/scripts/vm-pretest.sh"
grep -Fq 'docker run --rm hello-world' "$ROOT/.github/scripts/vm-pretest.sh"
grep -Fq 'sudo reboot' "$ROOT/.github/scripts/vm-pretest.sh"
grep -Fq "actions/upload-artifact@$UPLOAD_ARTIFACT_SHA" "$ROOT/.github/workflows/vm-pretest.yml"
grep -Fq 'Backup fail-closed invariants' "$ROOT/.github/workflows/non-regression.yml"

# Status checks required by the main ruleset must exist on every pull request.
# Keep required workflows unfiltered at trigger level; otherwise unrelated PRs
# can become permanently pending once the check is mandatory.
python3 - "$ROOT/.github/workflows/desktop-integration-pretest.yml" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
pr = re.search(r"(?ms)^  pull_request:\s*\n(?P<body>(?:^    .*\n)*)", text)
if pr is None:
    raise SystemExit("desktop integration workflow must run on pull_request")
if "paths:" in pr.group("body") or "paths-ignore:" in pr.group("body"):
    raise SystemExit("nautilus-ptyxis required check must not be path-filtered on pull_request")
if not re.search(r"(?ms)^  push:\s*\n(?:^    .*\n)*?^    branches:\s*\n^      - main\s*$", text):
    raise SystemExit("desktop integration workflow must validate every push to main")
PY

python3 - "$ROOT/.github/workflows/fedora-host-pretest.yml" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
pr = re.search(r"(?ms)^  pull_request:\s*\n(?P<body>(?:^    .*\n)*)", text)
if pr is None:
    raise SystemExit("host integration workflow must run on pull_request")
if "paths:" in pr.group("body") or "paths-ignore:" in pr.group("body"):
    raise SystemExit("packages-and-integration required check must not be path-filtered on pull_request")
push = re.search(r"(?ms)^  push:\s*\n(?P<body>(?:^    .*\n)*)", text)
if push is None:
    raise SystemExit("host integration workflow must run on push")
push_body = push.group("body")
if "paths:" in push_body or "paths-ignore:" in push_body:
    raise SystemExit("packages-and-integration required check must validate every push to main")
if "branches: [main]" not in push_body and not re.search(r"(?m)^    branches:\s*\n^      - main\s*$", push_body):
    raise SystemExit("host integration workflow push trigger must target main")
PY

for workflow in fedora-package-preflight.yml fedora-host-pretest.yml vm-pretest.yml; do
  grep -Fq 'schedule:' "$ROOT/.github/workflows/$workflow" || { echo "weekly external dependency schedule missing: $workflow" >&2; exit 1; }
done

write_workflows=0
while IFS= read -r workflow; do
  name="$(basename "$workflow")"
  grep -Fq 'permissions:' "$workflow" || { echo "missing workflow permissions: $workflow" >&2; exit 1; }
  grep -Fq "actions/checkout@$CHECKOUT_SHA" "$workflow" || { echo "checkout is not pinned to approved SHA: $workflow" >&2; exit 1; }

  if [[ "$name" == release.yml ]]; then
    grep -Fq 'contents: write' "$workflow" || { echo "release workflow lacks required contents: write: $workflow" >&2; exit 1; }
    ((write_workflows+=1))
  else
    grep -Fq 'contents: read' "$workflow" || { echo "missing contents: read: $workflow" >&2; exit 1; }
    if grep -Fq 'contents: write' "$workflow"; then
      echo "unexpected contents: write outside release workflow: $workflow" >&2
      exit 1
    fi
  fi
done < <(find "$ROOT/.github/workflows" -maxdepth 1 -type f -name '*.yml' -print | sort)

[[ "$write_workflows" -eq 1 ]] || { echo "expected exactly one contents: write workflow, found $write_workflows" >&2; exit 1; }

if grep -RInE 'uses:[[:space:]]+[^[:space:]#]+@v[0-9]+' "$ROOT/.github/workflows"; then echo 'mutable major-version GitHub Action reference found' >&2; exit 1; fi

echo 'CI maturity contract: PASS'

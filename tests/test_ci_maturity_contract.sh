#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKOUT_SHA="11d5960a326750d5838078e36cf38b85af677262"
UPLOAD_ARTIFACT_SHA="ea165f8d65b6e75b540449e92b4886f43607fa02"

for file in .github/workflows/non-regression.yml .github/workflows/fedora-host-pretest.yml .github/workflows/fedora-package-preflight.yml .github/workflows/desktop-integration-pretest.yml .github/workflows/vm-pretest.yml .github/workflows/shell-quality.yml .github/scripts/vm-pretest.sh; do
  [[ -f "$ROOT/$file" ]] || { echo "missing CI maturity file: $file" >&2; exit 1; }
done

grep -Fq 'fedora:45' "$ROOT/.github/workflows/fedora-host-pretest.yml"

# Hosted runners may hit both Docker Hub and ECR Public anonymous pull limits.
# Fedora 45 job containers use Fedora's official registry, as the installer audit
# already does. Keep Docker Hub out of CI; guest-VM pulls are unaffected.
if grep -nE '^[[:space:]]*container:[[:space:]]+fedora:' "$ROOT"/.github/workflows/*.yml; then
  echo 'workflow containers must not use anonymous Docker Hub Fedora images' >&2; exit 1
fi
if grep -nE 'docker pull (busybox|hello-world)' "$ROOT/.github/workflows/tests.yml"; then
  echo 'tests.yml must pull probe images from public.ecr.aws/docker/library' >&2; exit 1
fi
# The probe needs one registry pull (busybox, retried); the no-shell image is built FROM scratch,
# because a second anonymous pull is throttled too ("toomanyrequests: Rate exceeded").
grep -Fq 'FROM scratch' "$ROOT/.github/workflows/tests.yml"
if grep -n 'hello-world' "$ROOT/.github/workflows/tests.yml"; then
  echo 'tests.yml must not pull hello-world for the probe' >&2; exit 1
fi
grep -Fq 'container: registry.fedoraproject.org/fedora:45' "$ROOT/.github/workflows/fedora-installer-audit.yml"
# Every Fedora 45 workflow container must avoid ECR Public's data cap as well
# as Docker Hub's rate limit. Regressions fail before expensive VM jobs launch.
if grep -nE '^[[:space:]]*container:[[:space:]]+(public[.]ecr[.]aws/docker/library/fedora:45|fedora:45)([[:space:]]|$)' "$ROOT"/.github/workflows/*.yml; then
  echo 'Fedora 45 workflow containers must use registry.fedoraproject.org/fedora:45' >&2
  exit 1
fi
for workflow in desktop-integration-pretest fedora-appimage-pretest fedora-gaming-pretest fedora-host-pretest fedora-installer-audit fedora-package-preflight resource-monitor-fedora-pretest tests; do
  grep -Fq 'container: registry.fedoraproject.org/fedora:45' "$ROOT/.github/workflows/$workflow.yml" || {
    echo "missing official Fedora 45 registry for $workflow" >&2; exit 1;
  }
done
grep -Fq 'dnf -y --disablerepo=fedora-cisco-openh264 install dbus-daemon' "$ROOT/.github/workflows/desktop-integration-pretest.yml"
# Flathub can transiently refuse flathub.org connections. The CI bootstrap must
# keep the official signed .flatpakrepo and refuse success after exhausted retries.
for wf in fedora-package-preflight fedora-appimage-pretest fedora-host-pretest fedora45-package-preflight; do
  grep -Fq 'bash scripts/ci/ensure-flathub.sh' "$ROOT/.github/workflows/$wf.yml" || {
    echo "missing shared strict Flathub bootstrap in $wf" >&2; exit 1;
  }
done
grep -Fq 'https://dl.flathub.org/repo/flathub.flatpakrepo' "$ROOT/scripts/ci/ensure-flathub.sh"
grep -Fq 'https://dl.flathub.org/repo/flathub.flatpakrepo' "$ROOT/modules/system/04_package_sources.sh"
if grep -Eq -- '--no-gpg-verify|--disable-gpg-verify|--no-verify' "$ROOT/scripts/ci/ensure-flathub.sh"; then
  echo 'Flathub bootstrap must never bypass signatures' >&2; exit 1;
fi

# This reusable kernel preflight accepts both Fedora 45 and 45. It must use
# Fedora's official registry for either input; the old dynamic ECR reference
# bypassed the fixed-image checks and could fail before running any test.
grep -Fq 'container: registry.fedoraproject.org/fedora:' "$ROOT/.github/workflows/upstream-kernel.yml" || {
  echo 'upstream kernel preflight must use the official Fedora registry' >&2; exit 1;
}
grep -Fq 'inputs.fedora_release' "$ROOT/.github/workflows/upstream-kernel.yml" || {
  echo 'upstream kernel preflight must retain its release input' >&2; exit 1;
}
if grep -Fq 'public.ecr.aws/docker/library/fedora:' "$ROOT/.github/workflows/upstream-kernel.yml"; then
  echo 'upstream kernel preflight may not fetch Fedora from ECR Public' >&2
  exit 1
fi


grep -Fq 'Install Fedora-native base contract' "$ROOT/.github/workflows/fedora-host-pretest.yml"
grep -Fq 'bash .github/scripts/dnf-retry.sh dnf -y --refresh --disablerepo=fedora-cisco-openh264 install borgbackup jq acl xorriso dbus-daemon' "$ROOT/.github/workflows/fedora-host-pretest.yml"
grep -Fq 'Validate multimedia provider convergence' "$ROOT/.github/workflows/fedora-host-pretest.yml"
grep -Fq 'Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2' "$ROOT/.github/scripts/vm-pretest.sh"
grep -Fq 'scripts/kvm/verify_rocky_cloud_image.sh' "$ROOT/.github/scripts/vm-pretest.sh"
grep -Fq 'guest/rocky-devops/bootstrap-devops.sh' "$ROOT/.github/scripts/vm-pretest.sh"
grep -Fq 'docker run --rm hello-world' "$ROOT/.github/scripts/vm-pretest.sh"
grep -Fq 'sudo systemctl reboot' "$ROOT/.github/scripts/vm-pretest.sh"
grep -Fq "actions/upload-artifact@$UPLOAD_ARTIFACT_SHA" "$ROOT/.github/workflows/vm-pretest.yml"
grep -Fq 'Backup fail-closed invariants' "$ROOT/.github/workflows/non-regression.yml"

# Shell quality must not depend on unrelated third-party APT repositories
# preinstalled on the hosted runner. Only the Ubuntu archive is needed to
# install ShellCheck, and early setup failures must not be masked by a missing
# diagnostic artifact.
grep -Fq 'sources=/etc/apt/sources.list.d/ubuntu.sources' "$ROOT/.github/workflows/shell-quality.yml"
grep -Fq "Dir::Etc::sourcelist=\$sources" "$ROOT/.github/workflows/shell-quality.yml"
grep -Fq 'Dir::Etc::sourceparts=-' "$ROOT/.github/workflows/shell-quality.yml"
grep -Fq 'if-no-files-found: warn' "$ROOT/.github/workflows/shell-quality.yml"

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

# Every test file must actually be executed by a workflow; a test that CI
# never runs gives false confidence.
for test_file in "$ROOT"/tests/test_*.sh; do
  rel="tests/$(basename "$test_file")"
  grep -RqF "$rel" "$ROOT/.github/workflows" || { echo "test never executed by CI: $rel" >&2; exit 1; }
done

echo 'CI maturity contract: PASS'

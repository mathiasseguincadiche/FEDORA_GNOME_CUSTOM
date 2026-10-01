#!/usr/bin/env python3
"""Accept only successful push workflows for the exact release commit."""
import json
import sys

REQUIRED = {
    ".github/workflows/tests.yml",
    ".github/workflows/shell-quality.yml",
    ".github/workflows/non-regression.yml",
    ".github/workflows/fedora-package-preflight.yml",
    ".github/workflows/fedora-host-pretest.yml",
    ".github/workflows/desktop-integration-pretest.yml",
    ".github/workflows/fedora-installer-audit.yml",
}


def check(payload, sha, repository):
    selected = {}
    for run in payload["workflow_runs"]:
        path = run.get("path")
        if (path not in REQUIRED or run.get("head_sha") != sha
                or run.get("head_branch") != "main" or run.get("event") != "push"
                or (run.get("head_repository") or {}).get("full_name") != repository):
            continue
        if path not in selected or run["id"] > selected[path]["id"]:
            selected[path] = run
    pending = REQUIRED - selected.keys()
    for path, run in selected.items():
        if run.get("status") != "completed":
            pending.add(path)
        elif run.get("conclusion") != "success":
            print(f"Release blocked: {path} concluded {run.get('conclusion')}", file=sys.stderr)
            return 1
    if pending:
        print("Waiting for: " + ", ".join(sorted(pending)), file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(check(json.load(sys.stdin), sys.argv[1], sys.argv[2]))

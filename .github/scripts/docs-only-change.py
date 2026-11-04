#!/usr/bin/env python3
"""Decide whether a pull request only changes documentation.

Only a pull request whose every changed path is Markdown or under docs/ is
documentation-only. Any other event, an empty diff or an unreadable diff is
not: the full pipeline runs. The VM laboratories never read these files, and
the documentation tests run in logic-contracts whatever the answer.

Usage: docs-only-change.py EVENT BASE_SHA HEAD_SHA   (prints docs_only=true|false)
"""
import subprocess
import sys


def documentation(path):
    return path.endswith(".md") or path.startswith("docs/")


def docs_only(event, paths):
    return event == "pull_request" and bool(paths) and all(documentation(p) for p in paths)


def changed_paths(base, head):
    out = subprocess.run(["git", "diff", "--name-only", "--no-renames", base + "..." + head],
                         check=True, capture_output=True, text=True).stdout
    return [line for line in out.splitlines() if line]


def main(argv):
    if len(argv) != 4:
        raise SystemExit(__doc__)
    event, base, head = argv[1:]
    try:
        paths = changed_paths(base, head) if event == "pull_request" else []
    except (subprocess.CalledProcessError, OSError) as error:
        print(f"diff unavailable, running the full pipeline: {error}", file=sys.stderr)
        paths = []
    result = docs_only(event, paths)
    for path in paths:
        print(("docs " if documentation(path) else "code ") + path, file=sys.stderr)
    print("docs_only=" + ("true" if result else "false"))


if __name__ == "__main__":
    main(sys.argv)

#!/usr/bin/env python3
"""Check the external links of the tracked Markdown files.

A link is broken only when the server says the page is gone (404, 410) or the
name does not resolve. Anti-bot refusals (401, 403, 429) and server errors
(5xx) are reported as warnings: they say nothing about the page itself, and a
browser usually opens it. Exit 1 on a broken link, 0 otherwise.

Usage: check-external-links.py [REPOSITORY_ROOT]
"""
from pathlib import Path
import re
import socket
import subprocess
import sys
import urllib.error
import urllib.request

LINK = re.compile(r"\]\((https?://[^)\s]+)\)")
BROKEN = {404, 410}


def classify(status):
    """Return 'ok', 'warning' or 'broken' for an HTTP status, or None for a network failure."""
    if status is None:
        return "broken"
    if status in BROKEN:
        return "broken"
    if 200 <= status < 400:
        return "ok"
    return "warning"


def collect(root):
    files = subprocess.run(["git", "-C", str(root), "ls-files", "*.md"], check=True,
                           capture_output=True, text=True).stdout.split()
    links = {}
    for name in files:
        for line_no, line in enumerate((root / name).read_text(encoding="utf-8").splitlines(), 1):
            for url in LINK.findall(line):
                links.setdefault(url.split("#", 1)[0], f"{name}:{line_no}")
    return links


def status_of(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (documentation link check)"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status
    except urllib.error.HTTPError as error:
        return error.code
    except (urllib.error.URLError, socket.timeout, ConnectionError):
        return None


def main(argv):
    root = Path(argv[1] if len(argv) > 1 else ".").resolve()
    links = collect(root)
    broken = 0
    for url, where in sorted(links.items()):
        status = status_of(url)
        verdict = classify(status)
        if verdict == "broken":
            broken += 1
            print(f"::error::{where}: broken link {url} ({status or 'unreachable'})")
        elif verdict == "warning":
            print(f"::warning::{where}: {url} answered {status}; check it in a browser")
    print(f"external links: {len(links)} checked, {broken} broken")
    return 1 if broken else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

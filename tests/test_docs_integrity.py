#!/usr/bin/env python3
"""Documentation integrity, independent of wording.

Checks what can actually mislead an operator, never phrasing:
- local Markdown links resolve inside the repository;
- every guide in docs/ is reachable from README.md;
- every `./control.sh DOMAIN ACTION` quoted in Markdown is routed by the code;
- every repository path quoted in backticks exists;
- code and workflows only reference documentation files that exist.
"""
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
TRACKED = subprocess.run(["git", "-C", str(ROOT), "ls-files"], check=True,
                         capture_output=True, text=True).stdout.split()
MARKDOWN = [ROOT / p for p in TRACKED if p.endswith(".md")]
# Historical records keep their original wording and commands on purpose.
CURRENT = [p for p in MARKDOWN if "docs/history/" not in p.as_posix() and p.name != "CHANGELOG.md"]
errors = []


def rel(path):
    return path.relative_to(ROOT).as_posix()


def links(path):
    for target in LINK.findall(path.read_text(encoding="utf-8")):
        target = target.split("#", 1)[0]
        if target and not target.startswith(("http://", "https://", "mailto:")):
            yield target, (path.parent / target).resolve()


# 1. Local links resolve inside the repository.
for path in MARKDOWN:
    for target, resolved in links(path):
        if not resolved.is_relative_to(ROOT):
            errors.append(f"{rel(path)}: link escapes the repository: {target}")
        elif not resolved.exists():
            errors.append(f"{rel(path)}: broken link: {target}")

# 2. Every guide is reachable from the landing page.
seen, queue = set(), [ROOT / "README.md"]
while queue:
    page = queue.pop()
    if page in seen or page.suffix != ".md" or not page.exists():
        continue
    seen.add(page)
    queue.extend(resolved for _, resolved in links(page))
for path in sorted((ROOT / "docs").rglob("*.md")):
    if path not in seen:
        errors.append(f"{rel(path)}: not reachable from README.md")


# 3. Quoted Control Center commands are routed by control.sh / lib/control_center.sh.
def labels(block):
    found = set()
    for match in re.finditer(r"^\s+([a-z0-9|-]+)\)", block, re.M):
        found.update(match.group(1).split("|"))
    return found


routes = {}
control = (ROOT / "control.sh").read_text(encoding="utf-8")
for match in re.finditer(r'if \[\[ "\$\{1:-\}" == ([a-z]+)( && "\$\{2:-\}" == ([a-z-]+))? \]\]; then\n(.*?)\nfi\n', control, re.S):
    actions = routes.setdefault(match.group(1), set())
    actions.update({match.group(3)} if match.group(3) else labels(match.group(4)))
center = (ROOT / "lib/control_center.sh").read_text(encoding="utf-8")
for match in re.finditer(r'^    ([a-z-]+)\)\n      case "\$action" in\n(.*?)\n      esac', center, re.S | re.M):
    routes.setdefault(match.group(1), set()).update(labels(match.group(2)))
for match in re.finditer(r"^    ([a-z|-]+)\) cc_[a-z_]+ ;;", center, re.M):
    for domain in match.group(1).split("|"):
        routes.setdefault(domain, set())
if not routes:
    errors.append("control.sh routes could not be parsed")

COMMAND = re.compile(r"\./control\.sh((?:[ \t]+[a-z][a-z0-9|-]*){0,2})")
for path in CURRENT:
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        for match in COMMAND.finditer(line):
            words = match.group(1).split()
            if not words:
                continue
            domain = words[0]
            if domain not in routes:
                errors.append(f"{rel(path)}:{line_no}: unknown command ./control.sh {domain}")
                continue
            if len(words) > 1 and routes[domain]:
                for action in words[1].split("|"):
                    if action not in routes[domain]:
                        errors.append(f"{rel(path)}:{line_no}: unknown command ./control.sh {domain} {action}")

# 4. Repository paths quoted in backticks exist (placeholders and globs are skipped).
PATH = re.compile(r"`((?:\./)?(?:scripts|diagnostics|installer|config|lib|modules|manifests|profiles|tests|guest|systemd|remote|virtualization)/[A-Za-z0-9_./@-]+)")
for path in CURRENT:
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        for match in PATH.finditer(line):
            quoted = match.group(1).removeprefix("./").rstrip(".")
            if quoted.endswith("/") or "*" in quoted or re.search(r"[A-Z]{3,}", quoted.rsplit("/", 1)[-1]):
                continue
            if not (ROOT / quoted).exists() and quoted not in ("config/local.conf", "installer/fedora45-media.lock"):
                errors.append(f"{rel(path)}:{line_no}: missing repository path {quoted}")

# 5. Code, scripts and workflows only point at existing documentation.
DOC_REF = re.compile(r"docs/[A-Za-z0-9_/-]+\.md")
for name in TRACKED:
    if name.endswith(".md") or name.startswith("tests/test_docs_integrity"):
        continue
    file = ROOT / name
    try:
        text = file.read_text(encoding="utf-8")
    except (UnicodeDecodeError, IsADirectoryError):
        continue
    for ref in set(DOC_REF.findall(text)):
        if not (ROOT / ref).exists():
            errors.append(f"{name}: references missing documentation {ref}")

if errors:
    print("documentation integrity: FAIL", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    sys.exit(1)
print(f"documentation integrity: PASS ({len(seen)} reachable pages, {len(routes)} command domains)")

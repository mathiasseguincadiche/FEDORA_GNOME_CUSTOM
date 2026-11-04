#!/usr/bin/env python3
"""Documentation integrity, independent of wording.

Checks what can actually mislead an operator, never phrasing:
- local Markdown links resolve inside the repository;
- every guide in docs/ is reachable from README.md;
- every `./control.sh DOMAIN ACTION` quoted in Markdown is routed by the code;
- every repository path quoted in backticks exists;
- code and workflows only reference documentation files that exist;
- guides carry the metadata block defined in CONTRIBUTING.md;
- diagrams are .drawio/.svg pairs and no Mermaid block remains;
- the HOST software inventory reproduces the package manifests;
- tracked text files use LF line endings (.editorconfig).
"""
from datetime import date
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

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
PATH = re.compile(r"`((?:\./)?(?:scripts|diagnostics|installer|config|lib|modules|manifests|profiles|tests|guest|systemd|remote|virtualization|tools)/[A-Za-z0-9_./@-]+)")
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

DATE = r"\d{4}-\d{2}-\d{2}"
METADATA = re.compile(
    rf"^> Mise à jour : ({DATE}) · Responsable : @[A-Za-z0-9-]+\n"
    rf"> Dernière vérification : ({DATE}) — \S.* — matériel : (non vérifié|vérifié \(Gate 3, {DATE}\))\n")
TODAY = date.today().isoformat()


def body_after_title(path):
    text = path.read_text(encoding="utf-8")
    title, _, rest = text.partition("\n")
    return title, rest.lstrip("\n")


# 6. Guides carry the metadata block (CONTRIBUTING.md, « Métadonnées des guides »).
# Every guide, without exception: the documentation overhaul (C1-C9) migrated them all.
for path in sorted((ROOT / "docs").glob("*.md")):
    title, rest = body_after_title(path)
    match = METADATA.match(rest) if title.startswith("# ") else None
    if match is None:
        errors.append(f"{rel(path)}: missing or malformed metadata block under the title")
        continue
    updated, checked = match.group(1), match.group(2)
    for day in (updated, checked):
        try:
            date.fromisoformat(day)
        except ValueError:
            errors.append(f"{rel(path)}: invalid metadata date {day}")
            break
    else:
        if updated > TODAY or checked > TODAY:
            errors.append(f"{rel(path)}: metadata date in the future")
        elif checked < updated:
            errors.append(f"{rel(path)}: content updated on {updated} after its last check on {checked}")

# 7. No Mermaid: diagrams are .drawio sources with .svg exports (CONTRIBUTING.md, « Schémas »).
for path in CURRENT:
    if re.search(r"^\s*```\s*mermaid\b", path.read_text(encoding="utf-8"), re.M):
        errors.append(f"{rel(path)}: Mermaid block; use a .drawio source with its .svg export")

# 8. Each diagram is a valid .drawio/.svg pair with an accessible, opaque export.
SVG_NS = "{http://www.w3.org/2000/svg}"
diagrams = ROOT / "docs/assets/diagrams"
for path in sorted(diagrams.glob("*")) if diagrams.is_dir() else []:
    if path.suffix not in (".drawio", ".svg"):
        errors.append(f"{rel(path)}: only .drawio sources and .svg exports belong here")
        continue
    twin = path.with_suffix(".svg" if path.suffix == ".drawio" else ".drawio")
    if not twin.exists():
        errors.append(f"{rel(path)}: missing its pair {twin.name}")
    try:
        tree = ET.parse(path).getroot()
    except ET.ParseError as error:
        errors.append(f"{rel(path)}: invalid XML ({error})")
        continue
    if path.suffix == ".drawio":
        cells = tree.findall(".//mxCell")
        ids = [cell.get("id") for cell in cells]
        if tree.tag != "mxfile" or not tree.findall("diagram/mxGraphModel"):
            errors.append(f"{rel(path)}: not an uncompressed diagrams.net file")
        if len(ids) != len(set(ids)):
            errors.append(f"{rel(path)}: duplicate cell ids")
        for cell in cells:
            for ref in ("parent", "source", "target"):
                if cell.get(ref) and cell.get(ref) not in ids:
                    errors.append(f"{rel(path)}: cell {cell.get('id')} has an orphan {ref}")
    else:
        if tree.tag != SVG_NS + "svg" or not tree.get("viewBox"):
            errors.append(f"{rel(path)}: SVG root without a viewBox")
        if not (tree.findtext(SVG_NS + "title") or "").strip() or not (tree.findtext(SVG_NS + "desc") or "").strip():
            errors.append(f"{rel(path)}: SVG needs a non-empty <title> and <desc>")
        background = next((c for c in tree if c.tag == SVG_NS + "rect"), None)
        if background is None or background.get("fill") in (None, "none", "transparent"):
            errors.append(f"{rel(path)}: SVG needs an opaque background rectangle first")
        if re.search(r"<script|href=\"https?:", path.read_text(encoding="utf-8")):
            errors.append(f"{rel(path)}: SVG must not load scripts or remote resources")

# 9. The HOST inventory reproduces every package manifest exactly.
inventory = ROOT / "docs/SOFTWARE_INVENTORY.md"
listed, current = {}, None
for line in inventory.read_text(encoding="utf-8").splitlines():
    marker = re.match(r"^\*\*`manifests/([a-z0-9-]+\.txt)`\*\*", line)
    if marker:
        current = listed.setdefault(marker.group(1), [])
    elif line.startswith("#"):
        current = None
    elif current is not None and line.startswith("- "):
        current.append(line[2:].split(" — ", 1)[0].strip())
for manifest in sorted((ROOT / "manifests").glob("*.txt")):
    expected = [l.split("#", 1)[0].split()[0] for l in manifest.read_text(encoding="utf-8").splitlines()
                if l.split("#", 1)[0].strip()]
    found = listed.pop(manifest.name, None)
    if found is None:
        errors.append(f"docs/SOFTWARE_INVENTORY.md: manifests/{manifest.name} is not listed")
    elif found != expected:
        missing = [p for p in expected if p not in found]
        extra = [p for p in found if p not in expected]
        errors.append(f"docs/SOFTWARE_INVENTORY.md: manifests/{manifest.name} differs"
                      f" (missing {missing or 'none'}, extra {extra or 'none'}, or order)")
for name in sorted(listed):
    errors.append(f"docs/SOFTWARE_INVENTORY.md: lists missing manifest manifests/{name}")

# 10. Tracked text files use LF line endings, as .editorconfig requires.
for name in TRACKED:
    try:
        data = (ROOT / name).read_bytes()
    except (FileNotFoundError, IsADirectoryError):
        continue
    if b"\0" not in data and b"\r\n" in data:
        errors.append(f"{name}: CRLF line endings; use LF (.editorconfig)")

if errors:
    print("documentation integrity: FAIL", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    sys.exit(1)
print(f"documentation integrity: PASS ({len(seen)} reachable pages, {len(routes)} command domains)")

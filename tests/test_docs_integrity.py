#!/usr/bin/env python3
"""Documentation integrity, independent of wording.

Checks what can actually mislead an operator, never phrasing:
- local Markdown links resolve inside the repository;
- current guides have one H1, a coherent heading hierarchy and labelled,
  properly closed code fences;
- every guide in docs/ is reachable from README.md;
- every `./control.sh DOMAIN ACTION` quoted in Markdown is routed by the code;
- every routed command is listed on the Control Center page, its source of truth;
- every repository path quoted in backticks exists;
- code and workflows only reference documentation files that exist;
- the README and every guide carry the metadata block defined in CONTRIBUTING.md;
- diagrams are .drawio/.svg pairs, every asset under docs/assets/ is referenced
  by a Markdown page, and every SVG export is accessible (viewBox, title, desc,
  opaque background, no remote resources); no Mermaid block remains;
- no typographic apostrophe (U+2019) remains outside the archives;
- the HOST software inventory reproduces the package manifests;
- tracked text files use LF line endings (.editorconfig).
"""
from datetime import date
from pathlib import Path
import html
import re
import subprocess
import sys
from urllib.parse import unquote
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


# 1. Local links resolve inside the repository; their targets are recorded
#    for the reverse check on assets (rule 8c).
referenced = set()
for path in MARKDOWN:
    for target, resolved in links(path):
        referenced.add(resolved)
        if not resolved.is_relative_to(ROOT):
            errors.append(f"{rel(path)}: link escapes the repository: {target}")
        elif not resolved.exists():
            errors.append(f"{rel(path)}: broken link: {target}")


def markdown_anchors(path):
    """Build the anchors rendered for Markdown headings, including duplicate slugs.

    GitHub keeps accented letters in heading fragments and adds -1, -2, etc.
    to duplicate headings. Explicit HTML id/name anchors are supported too.
    """
    anchors, counts = set(), {}
    fenced = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if re.match(r"^\s*(`{3,}|~{3,})", line):
            fenced = not fenced
            continue
        if fenced:
            continue
        for attr in re.findall(r'<(?:a|span|div|h[1-6])\b[^>]*\b(?:id|name)=["\']([^"\']+)["\']', line, re.I):
            anchors.add(html.unescape(attr))
        heading = re.match(r"^\s{0,3}#{1,6}\s+(.+?)\s*#*\s*$", line)
        if heading is None:
            continue
        title = heading.group(1)
        title = re.sub(r"!?(?:\[([^\]]+)\]\([^)]+\))", r"\1", title)
        title = re.sub(r"<[^>]+>", "", title)
        title = html.unescape(title)
        title = re.sub(r"[`*_~]", "", title)
        # GitHub's generated fragments retain letters (including accents),
        # digits, underscores and hyphens; punctuation is removed.
        slug = re.sub(r"[^\w\s-]", "", title.lower()).replace(" ", "-")
        if not slug:
            continue
        index = counts.get(slug, 0)
        counts[slug] = index + 1
        anchors.add(f"{slug}-{index}" if index else slug)
    return anchors


# 1a. Enforce the editorial contract on current guides: a single H1, navigable
# heading hierarchy, and a language for every closed code block. Literal Markdown
# examples inside fences must not be mistaken for headings or new fences.
for path in (p for p in CURRENT if "docs/adr/" not in p.as_posix()):
    previous_level = None
    fence_char = None
    fence_length = 0
    h1_count = 0
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        marker = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", line)
        if marker:
            token = marker.group(1)
            if fence_char is None:
                if not marker.group(2).strip():
                    errors.append(f"{rel(path)}:{line_no}: code fence without a language")
                fence_char, fence_length = token[0], len(token)
            elif token[0] == fence_char and len(token) >= fence_length and not marker.group(2).strip():
                fence_char, fence_length = None, 0
            continue
        if fence_char is not None:
            continue
        heading = re.match(r"^ {0,3}(#{1,6})[ \t]+", line)
        if heading is None:
            continue
        level = len(heading.group(1))
        if level == 1:
            h1_count += 1
        if previous_level is not None and level > previous_level + 1:
            errors.append(f"{rel(path)}:{line_no}: Markdown heading jumps from H{previous_level} to H{level}")
        previous_level = level
    if fence_char is not None:
        errors.append(f"{rel(path)}: unclosed code fence")
    if path == ROOT / "README.md" or path.parent == ROOT / "docs":
        if h1_count != 1:
            errors.append(f"{rel(path)}: expected exactly one H1 heading, found {h1_count}")


# 1b. A Markdown link can name an existing file yet point to a missing section.
# Check the fragment as well, including links that refer only to #heading.
anchor_cache = {}
for path in MARKDOWN:
    for link in LINK.findall(path.read_text(encoding="utf-8")):
        if "#" not in link or link.startswith(("http://", "https://", "mailto:")):
            continue
        name, fragment = link.split("#", 1)
        if not fragment:
            continue
        destination = (path.parent / name).resolve() if name else path
        if not destination.is_relative_to(ROOT) or not destination.is_file() or destination.suffix != ".md":
            continue  # missing targets and escapes are diagnosed by rule 1
        fragment = unquote(fragment)
        if destination not in anchor_cache:
            anchor_cache[destination] = markdown_anchors(destination)
        if fragment not in anchor_cache[destination]:
            errors.append(f"{rel(path)}: missing Markdown anchor: {link}")

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

# 3b. The Control Center page is the reference for commands: it lists every route.
# Option-style aliases (-h, --help) are spelled out once, through the `help` action.
listed = set()
CENTER_PAGE = ROOT / "docs/CONTROL_CENTER.md"
for match in COMMAND.finditer(CENTER_PAGE.read_text(encoding="utf-8")):
    words = match.group(1).split()
    if words:
        listed.add((words[0], None))
        for action in (words[1].split("|") if len(words) > 1 else []):
            listed.add((words[0], action))
for domain, actions in sorted(routes.items()):
    if domain.startswith("-"):
        continue
    if (domain, None) not in listed:
        errors.append(f"{rel(CENTER_PAGE)}: does not document ./control.sh {domain}")
    for action in sorted(a for a in actions if not a.startswith("-")):
        if (domain, action) not in listed:
            errors.append(f"{rel(CENTER_PAGE)}: does not document ./control.sh {domain} {action}")

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


# 6. The README and every guide carry the metadata block (CONTRIBUTING.md, « Métadonnées des guides »).
# Every guide, without exception: the documentation overhaul (C1-C9) migrated them all.
for path in sorted((ROOT / "docs").glob("*.md")) + [ROOT / "README.md"]:
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

# 8. Each diagram is a valid .drawio/.svg pair; every SVG export is accessible,
# opaque and self-contained, and every asset is referenced by a Markdown page.
SVG_NS = "{http://www.w3.org/2000/svg}"
assets = ROOT / "docs/assets"
diagrams = assets / "diagrams"


def check_svg(path):
    try:
        tree = ET.parse(path).getroot()
    except ET.ParseError as error:
        errors.append(f"{rel(path)}: invalid XML ({error})")
        return
    if tree.tag != SVG_NS + "svg" or not tree.get("viewBox"):
        errors.append(f"{rel(path)}: SVG root without a viewBox")
    if not (tree.findtext(SVG_NS + "title") or "").strip() or not (tree.findtext(SVG_NS + "desc") or "").strip():
        errors.append(f"{rel(path)}: SVG needs a non-empty <title> and <desc>")
    background = next((c for c in tree if c.tag == SVG_NS + "rect"), None)
    if background is None or background.get("fill") in (None, "none", "transparent"):
        errors.append(f"{rel(path)}: SVG needs an opaque background rectangle first")
    if re.search(r"<script|href=\"https?:", path.read_text(encoding="utf-8")):
        errors.append(f"{rel(path)}: SVG must not load scripts or remote resources")


for path in sorted(diagrams.glob("*")) if diagrams.is_dir() else []:
    if path.suffix not in (".drawio", ".svg"):
        errors.append(f"{rel(path)}: only .drawio sources and .svg exports belong here")
        continue
    twin = path.with_suffix(".svg" if path.suffix == ".drawio" else ".drawio")
    if not twin.exists():
        errors.append(f"{rel(path)}: missing its pair {twin.name}")
    if path.suffix == ".svg":
        check_svg(path)
        continue
    try:
        tree = ET.parse(path).getroot()
    except ET.ParseError as error:
        errors.append(f"{rel(path)}: invalid XML ({error})")
        continue
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

# 8b. Every SVG export under docs/assets/, not only the diagram pairs, is checked.
for path in sorted(assets.rglob("*.svg")):
    if diagrams not in path.parents:
        check_svg(path)

# 8c. Every asset under docs/assets/ is referenced by at least one Markdown page
# (rule 1 already checks that every referenced file exists).
for path in sorted(p for p in assets.rglob("*") if p.is_file()):
    if path not in referenced:
        errors.append(f"{rel(path)}: asset not referenced from any Markdown page")

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

# 11. Straight apostrophes only outside the archives (CONTRIBUTING.md, « Charte des apostrophes »).
# CHANGELOG.md, docs/adr/ and docs/history/ keep their original wording on purpose.
for name in TRACKED:
    if name == "CHANGELOG.md" or name.startswith(("docs/adr/", "docs/history/")):
        continue
    try:
        data = (ROOT / name).read_bytes()
    except (FileNotFoundError, IsADirectoryError):
        continue
    if b"\0" in data:
        continue
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        continue
    if chr(0x2019) in text:
        errors.append(f"{name}: typographic apostrophe U+2019 outside the archives (straight apostrophes only)")

if errors:
    print("documentation integrity: FAIL", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    sys.exit(1)
print(f"documentation integrity: PASS ({len(seen)} reachable pages, {len(routes)} command domains)")

#!/usr/bin/env python3
"""Documentation integrity, independent of wording.

Checks what can actually mislead an operator, never phrasing:
- local Markdown links resolve inside the repository;
- every guide in docs/ is reachable from README.md;
- every `./control.sh DOMAIN ACTION` quoted in Markdown is routed by the code;
- every repository path quoted in backticks exists;
- code and workflows only reference documentation files that exist;
- guides carry the metadata block defined in CONTRIBUTING.md;
- diagrams are .drawio/.svg pairs and no Mermaid block remains.
"""
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

# Migration lists for the documentation overhaul: a guide leaves a list when it is
# rewritten, and a listed guide that already complies is an error, so the lists only shrink.
METADATA_PENDING = {
    "APPIMAGE.md", "ARCHITECTURE.md", "BACKUP_RESTORE.md", "CI_VALIDATION.md", "CONTROL_CENTER.md",
    "DESKTOP_LIFECYCLE.md", "DISPLAY_COLOR_DIAGNOSTIC.md", "FEDORA45_LIVE_PREFLIGHT.md",
    "FEDORA45_PRIMARY.md", "FEDORA_GNOME_CI_LAB.md", "GAMING.md", "GLOSSARY.md", "GNOME.md",
    "GTK4_APPLICATIONS.md", "HOST_BASH_UX.md", "HOST_SECURITY_POLICY.md", "INSTALLATION_GUIDE.md",
    "ISOLATED_RECOVERY_RUNBOOK.md", "KVM_NETWORK.md", "KVM_QUICKSTART.md", "MULTIMEDIA_CODECS.md",
    "NAUTILUS.md", "PERFORMANCE.md", "PHYSICAL_QUALIFICATION_CHECKLIST.md", "PTYXIS.md",
    "QUALIFICATION.md", "REMOTE_ACCESS.md", "ROADMAP_FEDORA45_2026.md",
    "SOFTWARE_INVENTORY.md", "SUPPLY_CHAIN.md", "TROUBLESHOOTING.md", "UPGRADE_FEDORA_45.md",
    "UPSTREAM_LINUX.md", "VIRTUALIZATION.md",
}
MERMAID_PENDING = {
    "docs/ARCHITECTURE.md", "docs/BACKUP_RESTORE.md", "docs/CI_VALIDATION.md", "docs/CONTROL_CENTER.md",
    "docs/FEDORA_GNOME_CI_LAB.md", "docs/QUALIFICATION.md", "docs/REMOTE_ACCESS.md",
}
DATE = r"\d{4}-\d{2}-\d{2}"
METADATA = re.compile(
    rf"^> Mise à jour : {DATE} · Responsable : @[A-Za-z0-9-]+\n"
    rf"> Dernière vérification : {DATE} — \S.* — matériel : (non vérifié|vérifié \(Gate 3, {DATE}\))\n")


def body_after_title(path):
    text = path.read_text(encoding="utf-8")
    title, _, rest = text.partition("\n")
    return title, rest.lstrip("\n")


# 6. Guides carry the metadata block (CONTRIBUTING.md, « Métadonnées des guides »).
guides = sorted(p for p in (ROOT / "docs").glob("*.md"))
for name in sorted(METADATA_PENDING - {p.name for p in guides}):
    errors.append(f"METADATA_PENDING lists a missing guide: docs/{name}")
for path in guides:
    title, rest = body_after_title(path)
    valid = title.startswith("# ") and METADATA.match(rest) is not None
    if path.name in METADATA_PENDING:
        if valid:
            errors.append(f"{rel(path)}: metadata present; remove it from METADATA_PENDING")
    elif not valid:
        errors.append(f"{rel(path)}: missing or malformed metadata block under the title")
    if valid:
        for day in re.findall(DATE, "\n".join(rest.splitlines()[:2])):
            if not re.fullmatch(r"20\d\d-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])", day):
                errors.append(f"{rel(path)}: invalid metadata date {day}")

# 7. No Mermaid: diagrams are .drawio sources with .svg exports (CONTRIBUTING.md, « Schémas »).
for path in CURRENT:
    has_mermaid = re.search(r"^\s*```\s*mermaid\b", path.read_text(encoding="utf-8"), re.M) is not None
    if rel(path) in MERMAID_PENDING:
        if not has_mermaid:
            errors.append(f"{rel(path)}: no Mermaid left; remove it from MERMAID_PENDING")
    elif has_mermaid:
        errors.append(f"{rel(path)}: Mermaid block; use a .drawio source with its .svg export")
for name in sorted(MERMAID_PENDING):
    if not (ROOT / name).exists():
        errors.append(f"MERMAID_PENDING lists a missing file: {name}")

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

if errors:
    print("documentation integrity: FAIL", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    sys.exit(1)
print(f"documentation integrity: PASS ({len(seen)} reachable pages, {len(routes)} command domains)")

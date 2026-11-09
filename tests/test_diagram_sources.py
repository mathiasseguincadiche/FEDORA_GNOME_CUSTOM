#!/usr/bin/env python3
"""The committed diagrams are exactly what tools/diagrams produces, and pass its checks.

A hand-edited export, a source and an export that drift apart, or a palette
change that breaks WCAG contrast all fail here.
"""
from pathlib import Path
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools/diagrams"
COMMITTED = ROOT / "docs/assets/diagrams"

with tempfile.TemporaryDirectory() as tmp:
    built = Path(tmp) / "diagrams"
    subprocess.run([sys.executable, "-B", str(TOOLS / "build.py"), str(built)], check=True,
                   capture_output=True, cwd=TOOLS)
    produced = {p.name for p in built.iterdir()}
    present = {p.name for p in COMMITTED.iterdir()}
    errors = [f"missing in docs/assets/diagrams: {n}" for n in sorted(produced - present)]
    errors += [f"not produced by tools/diagrams/build.py: {n}" for n in sorted(present - produced)]
    errors += [f"differs from the generator output: docs/assets/diagrams/{n}"
               for n in sorted(produced & present) if (built / n).read_bytes() != (COMMITTED / n).read_bytes()]

check = subprocess.run([sys.executable, "-B", str(TOOLS / "verify.py"), str(COMMITTED)],
                       capture_output=True, text=True, cwd=TOOLS)
if check.returncode:
    errors.append("tools/diagrams/verify.py failed:\n" + check.stdout + check.stderr)

# Every guide must have a genuinely legible portrait fallback, without losing
# its wide layout or either editable source. This checks the *contract*; the
# rendered pixels at 300px are still reviewed by a person with Inkscape.
GUIDES = {
    "architecture-poste": "ARCHITECTURE.md",
    "sauvegarde-restauration": "BACKUP_RESTORE.md",
    "ci-fusion-release": "CI_VALIDATION.md",
    "centre-de-controle": "CONTROL_CENTER.md",
    "laboratoire-gnome": "FEDORA_GNOME_CI_LAB.md",
    "chaine-qualification": "QUALIFICATION.md",
    "acces-distant": "REMOTE_ACCESS.md",
}
SVG_NS = "{http://www.w3.org/2000/svg}"
for slug, guide in GUIDES.items():
    mobile_svg = COMMITTED / f"{slug}-mobile.svg"
    desktop_svg = COMMITTED / f"{slug}.svg"
    if not (mobile_svg.exists() and desktop_svg.exists()):
        errors.append(f"{slug}: missing desktop or mobile diagram")
        continue
    mobile = ET.parse(mobile_svg).getroot()
    desktop = ET.parse(desktop_svg).getroot()
    width = int(mobile.attrib["width"])
    if width != 360:
        errors.append(f"{slug}: mobile width {width}px, expected 360px")
    desc_mobile = mobile.find(SVG_NS + "desc")
    desc_desktop = desktop.find(SVG_NS + "desc")
    if desc_mobile is None or desc_desktop is None or desc_mobile.text != desc_desktop.text:
        errors.append(f"{slug}: mobile and desktop semantics have different descriptions")
    # Large headers or group labels are not body copy. Body copy is generated
    # at 17px, which is 14.17px after a 360 -> 300px scale.
    mobile_text = mobile_svg.read_text(encoding="utf-8")
    if 'font-size="17"' not in mobile_text or 17 * 300 / width < 14:
        errors.append(f"{slug}: mobile body font below 14px at 300px")
    for label in mobile.iter(SVG_NS + "text"):
        if label.get("fill") == "#2959B4" and int(label.get("font-size", 0)) * 300 / width < 14:
            errors.append(f"{slug}: section title below 14px at 300px")

    page = (ROOT / "docs" / guide).read_text(encoding="utf-8")
    if (f'<source media="(min-width: 700px)" srcset="assets/diagrams/{slug}.svg">' not in page
            or f'<img src="assets/diagrams/{slug}-mobile.svg" alt="' not in page):
        errors.append(f"{guide}: responsive image lacks mobile fallback or wide view")
    for extension in ("svg", "drawio"):
        for suffix in ("", "-mobile"):
            if f"(assets/diagrams/{slug}{suffix}.{extension})" not in page:
                errors.append(f"{guide}: missing accessible link to {slug}{suffix}.{extension}")

if errors:
    print("diagram sources: FAIL", file=sys.stderr)
    print("\n".join("- " + e for e in errors), file=sys.stderr)
    sys.exit(1)
print(f"diagram sources: PASS ({len(produced) // 2} pairs reproduced byte for byte, contrast and labels checked)")

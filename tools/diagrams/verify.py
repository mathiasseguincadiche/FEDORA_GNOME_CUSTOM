"""Check meaningful colour contrast and text parity between editable sources and SVG."""
import html
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from diagramkit import LINE, STYLES, TEXT

folder = Path(sys.argv[1])


def luminance(hex_colour):
    channels = [int(hex_colour[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]


def ratio(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


fills = {style[0] for style in STYLES.values()} | {"#FFFFFF", "#F7F9FC"}
borders = {style[1] for style in STYLES.values()} | {"#D9E3EF"}
worst_text = min(ratio(TEXT, f) for f in fills)
group_title = ratio("#2959B4", "#FFFFFF")
worst_border = min(ratio(b, "#FFFFFF") for b in borders)
print(f"text {TEXT} on fills: min {worst_text:.2f}:1 (needs 4.5)")
print(f"group titles #2959B4 on white: {group_title:.2f}:1 (needs 4.5)")
print(f"arrows {LINE} on #F7F9FC: {ratio(LINE, '#F7F9FC'):.2f}:1 (needs 3)")
print(f"borders on white: min {worst_border:.2f}:1 (decorative frames may be < 3)")
assert worst_text >= 4.5 and group_title >= 4.5 and ratio(LINE, "#FFFFFF") >= 3

SVG = "{http://www.w3.org/2000/svg}"
for svg_path in sorted(folder.glob("*.svg")):
    svg_text = [t.text for t in ET.parse(svg_path).getroot().iter(SVG + "text") if t.text]
    model = ET.parse(svg_path.with_suffix(".drawio")).getroot()
    drawio_text = []
    for cell in model.iter("mxCell"):
        value = cell.get("value") or ""
        for part in re.split(r"<br>", value):
            plain = html.unescape(re.sub(r"<[^>]+>", "", part)).strip()
            if plain:
                drawio_text.append(plain)
    if sorted(svg_text) != sorted(drawio_text):
        print("MISMATCH", svg_path.name, set(svg_text) ^ set(drawio_text))
        sys.exit(1)
    print(f"ok {svg_path.stem}: {len(svg_text)} labels identical in .svg and .drawio")

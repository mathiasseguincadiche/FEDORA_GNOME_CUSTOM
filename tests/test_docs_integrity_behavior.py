#!/usr/bin/env python3
"""Run tests/test_docs_integrity.py on disposable copies of the repository.

Each case changes one thing (a Mermaid block, a metadata block, a diagram file) and
checks that the integrity test accepts or rejects it, with the expected message.
"""
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TRACKED = subprocess.run(["git", "-C", str(ROOT), "ls-files"], check=True,
                         capture_output=True, text=True).stdout.split()
METADATA = ("> Mise à jour : 2026-11-03 · Responsable : @mathiasseguincadiche\n"
            "> Dernière vérification : 2026-11-03 — relecture contre le code de `main` — matériel : non vérifié\n")
SVG = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 40">'
       '<title>Exemple</title><desc>A mène à B.</desc>'
       '<rect width="100" height="40" fill="#ffffff"/><text x="10" y="25">A → B</text></svg>\n')
DRAWIO = ('<mxfile host="app.diagrams.net"><diagram id="d" name="Exemple"><mxGraphModel><root>'
          '<mxCell id="0"/><mxCell id="1" parent="0"/>'
          '<mxCell id="a" value="A" vertex="1" parent="1"><mxGeometry x="0" y="0" width="40" height="20" as="geometry"/></mxCell>'
          '<mxCell id="b" value="B" vertex="1" parent="1"><mxGeometry x="60" y="0" width="40" height="20" as="geometry"/></mxCell>'
          '<mxCell id="e" edge="1" parent="1" source="a" target="{target}"><mxGeometry relative="1" as="geometry"/></mxCell>'
          '</root></mxGraphModel></diagram></mxfile>\n')
failures = []


def fixture():
    work = Path(tempfile.mkdtemp())
    for name in TRACKED:
        source = ROOT / name
        if source.is_file():
            (work / name).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, work / name)
    subprocess.run(["git", "init", "-q", str(work)], check=True)
    return work


def track(work):
    subprocess.run(["git", "-C", str(work), "add", "-A"], check=True)


def run(work):
    result = subprocess.run([sys.executable, "-B", str(work / "tests/test_docs_integrity.py")],
                            capture_output=True, text=True)
    return result.returncode, result.stdout + result.stderr


def edit(path, old, new):
    text = path.read_text(encoding="utf-8")
    assert text.count(old) == 1, (path, old)
    path.write_text(text.replace(old, new, 1), encoding="utf-8")


def add_metadata(path):
    title, _, rest = path.read_text(encoding="utf-8").partition("\n")
    path.write_text(title + "\n\n" + METADATA + "\n" + rest.lstrip("\n"), encoding="utf-8")


def unlist(work, entry):
    test = work / "tests/test_docs_integrity.py"
    text = test.read_text(encoding="utf-8")
    new = re.sub(r'\s*"' + re.escape(entry) + r'",', "", text, count=1)
    assert new != text, entry
    test.write_text(new, encoding="utf-8")


def case(name, change, expect_pass, message=None):
    work = fixture()
    try:
        change(work)
        track(work)
        code, output = run(work)
        if (code == 0) != expect_pass:
            failures.append(f"{name}: expected {'PASS' if expect_pass else 'FAIL'}, got rc={code}\n{output}")
        elif message and message not in output:
            failures.append(f"{name}: missing message {message!r}\n{output}")
    finally:
        shutil.rmtree(work)


def diagram(work, svg=SVG, drawio=DRAWIO.format(target="b"), pair=True):
    folder = work / "docs/assets/diagrams"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "exemple.svg").write_text(svg, encoding="utf-8")
    if pair:
        (folder / "exemple.drawio").write_text(drawio, encoding="utf-8")


gnome = "docs/GNOME.md"
case("unchanged repository", lambda w: None, True)
case("new Mermaid block", lambda w: edit(w / gnome, "## Les six extensions", "```mermaid\nflowchart LR\n  A --> B\n```\n\n## Les six extensions"),
     False, "docs/GNOME.md: Mermaid block")
case("stale Mermaid list", lambda w: edit(w / "tests/test_docs_integrity.py", "MERMAID_PENDING = set()",
                                            'MERMAID_PENDING = {"docs/GNOME.md"}'),
     False, "no Mermaid left; remove it from MERMAID_PENDING")
case("guide leaves the list without metadata", lambda w: unlist(w, "GNOME.md"),
     False, "docs/GNOME.md: missing or malformed metadata block")
case("listed guide already migrated", lambda w: add_metadata(w / gnome),
     False, "metadata present; remove it from METADATA_PENDING")
case("migrated guide", lambda w: (add_metadata(w / gnome), unlist(w, "GNOME.md")), True)
case("malformed metadata", lambda w: (add_metadata(w / gnome), unlist(w, "GNOME.md"),
                                      edit(w / gnome, "matériel : non vérifié", "matériel : OK")),
     False, "docs/GNOME.md: missing or malformed metadata block")
case("impossible date", lambda w: (add_metadata(w / gnome), unlist(w, "GNOME.md"),
                                   edit(w / gnome, "Mise à jour : 2026-11-03", "Mise à jour : 2026-13-03")),
     False, "invalid metadata date 2026-13-03")
case("valid diagram pair", lambda w: diagram(w), True)
case("export without source", lambda w: diagram(w, pair=False), False, "missing its pair exemple.drawio")
case("transparent export", lambda w: diagram(w, svg=SVG.replace('fill="#ffffff"', 'fill="none"')),
     False, "opaque background rectangle")
case("export without description", lambda w: diagram(w, svg=SVG.replace("<desc>A mène à B.</desc>", "")),
     False, "non-empty <title> and <desc>")
case("source with an orphan edge", lambda w: diagram(w, drawio=DRAWIO.format(target="missing")),
     False, "has an orphan target")
case("compressed or foreign source", lambda w: diagram(w, drawio="<mxfile><diagram>eJzLSM3JyQcABiwCFQ==</diagram></mxfile>\n"),
     False, "not an uncompressed diagrams.net file")

if failures:
    print("documentation integrity behavior: FAIL", file=sys.stderr)
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
print("documentation integrity behavior: PASS (14 cases)")

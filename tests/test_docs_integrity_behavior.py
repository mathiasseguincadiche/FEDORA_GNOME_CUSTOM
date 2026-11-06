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
cases = []


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


def append(path, text):
    path.write_text(path.read_text(encoding="utf-8") + text, encoding="utf-8")


def add_metadata(path):
    title, _, rest = path.read_text(encoding="utf-8").partition("\n")
    path.write_text(title + "\n\n" + METADATA + "\n" + rest.lstrip("\n"), encoding="utf-8")


def strip_metadata(path):
    title, _, rest = path.read_text(encoding="utf-8").partition("\n")
    lines = rest.lstrip("\n").split("\n")
    assert lines[0].startswith("> Mise à jour") and lines[1].startswith("> Dernière vérification"), path
    path.write_text(title + "\n\n" + "\n".join(lines[2:]).lstrip("\n"), encoding="utf-8")


def remigrate(path):
    """Replace the guide's metadata by the fixture block, so later edits do not depend on its dates."""
    strip_metadata(path)
    add_metadata(path)


def crlf(path):
    path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))


def case(name, change, expect_pass, message=None):
    cases.append(name)
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
    # Rule 8c: an asset must be referenced by a Markdown page, so the fixture
    # links the new pair from an existing guide.
    page = work / gnome
    page.write_text(page.read_text(encoding="utf-8")
                    + "\n![Exemple](assets/diagrams/exemple.svg) — source : [exemple.drawio](assets/diagrams/exemple.drawio)\n",
                    encoding="utf-8")


gnome = "docs/GNOME.md"
case("unchanged repository", lambda w: None, True)
case("valid accented Markdown anchor", lambda w: append(w / gnome,
     "\n[Revenir aux extensions](#les-six-extensions)\n"), True)
case("missing Markdown anchor in another file",
     lambda w: append(w / "README.md", "\n[Section absente](docs/INSTALLATION_GUIDE.md#section-inexistante)\n"),
     False, "README.md: missing Markdown anchor")
case("missing same-file Markdown anchor",
     lambda w: append(w / gnome, "\n[Section absente](#section-inexistante)\n"),
     False, "docs/GNOME.md: missing Markdown anchor")
case("duplicate heading receives second anchor",
     lambda w: append(w / gnome, "\n## Exemple répété\n\n## Exemple répété\n\n[Deuxième](#exemple-répété-1)\n"),
     True)
case("nonexistent duplicate heading anchor",
     lambda w: append(w / gnome, "\n## Exemple répété\n\n## Exemple répété\n\n[Troisième](#exemple-répété-2)\n"),
     False, "docs/GNOME.md: missing Markdown anchor")
case("code fence does not define a heading",
     lambda w: append(w / gnome, "\n```markdown\n## Section fictive\n```\n\n[Lien](#section-fictive)\n"),
     False, "docs/GNOME.md: missing Markdown anchor")
case("new Mermaid block", lambda w: edit(w / gnome, "## Les six extensions", "```mermaid\nflowchart LR\n  A --> B\n```\n\n## Les six extensions"),
     False, "docs/GNOME.md: Mermaid block")
case("guide loses its metadata", lambda w: strip_metadata(w / gnome),
     False, "docs/GNOME.md: missing or malformed metadata block")
case("new guide without metadata", lambda w: (w / "docs/NOUVEAU.md").write_text("# Nouveau\n\nTexte.\n", encoding="utf-8"),
     False, "docs/NOUVEAU.md: missing or malformed metadata block")
case("guide with the fixture metadata", lambda w: remigrate(w / gnome), True)
case("content updated after its last check",
     lambda w: (remigrate(w / gnome), edit(w / gnome, "Mise à jour : 2026-11-03", "Mise à jour : 2026-11-04")),
     False, "content updated on 2026-11-04 after its last check on 2026-11-03")
case("metadata date in the future",
     lambda w: (remigrate(w / gnome), edit(w / gnome, "Dernière vérification : 2026-11-03", "Dernière vérification : 2999-01-01")),
     False, "docs/GNOME.md: metadata date in the future")
case("CRLF line endings", lambda w: crlf(w / gnome), False, "docs/GNOME.md: CRLF line endings")
case("malformed metadata", lambda w: (remigrate(w / gnome), edit(w / gnome, "matériel : non vérifié", "matériel : OK")),
     False, "docs/GNOME.md: missing or malformed metadata block")
case("impossible date", lambda w: (remigrate(w / gnome), edit(w / gnome, "Mise à jour : 2026-11-03", "Mise à jour : 2026-13-03")),
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
case("manifest gains an undocumented package",
     lambda w: edit(w / "manifests/packages-shell.txt", "direnv\n", "direnv\nexemple-paquet\n"),
     False, "manifests/packages-shell.txt differs (missing ['exemple-paquet']")
case("inventory lists a package no manifest installs",
     lambda w: edit(w / "docs/SOFTWARE_INVENTORY.md", "- zoxide\n", "- zoxide\n- xorriso\n"),
     False, "extra ['xorriso']")
case("new manifest left out of the inventory",
     lambda w: (w / "manifests/packages-exemple.txt").write_text("exemple\n", encoding="utf-8"),
     False, "manifests/packages-exemple.txt is not listed")
case("routed command missing from the Control Center page",
     lambda w: edit(w / "lib/control_center.sh", "        tail) cc_tail_latest_log ;;\n",
                    "        tail) cc_tail_latest_log ;;\n        exemple) cc_show_logs ;;\n"),
     False, "docs/CONTROL_CENTER.md: does not document ./control.sh logs exemple")
case("Control Center page drops a documented command",
     lambda w: edit(w / "docs/CONTROL_CENTER.md", "./control.sh logs tail\n", ""),
     False, "docs/CONTROL_CENTER.md: does not document ./control.sh logs tail")
case("README loses its metadata", lambda w: strip_metadata(w / "README.md"),
     False, "README.md: missing or malformed metadata block")


def orphan_asset(work):
    (work / "docs/assets/orphelin.svg").write_text(SVG, encoding="utf-8")


case("asset not referenced by any page", orphan_asset,
     False, "docs/assets/orphelin.svg: asset not referenced from any Markdown page")


def apostrophe_in_code(work):
    (work / "scripts/exemple.sh").write_text("#!/usr/bin/env bash\n# d" + chr(0x2019) + "erreur\n", encoding="utf-8")


case("typographic apostrophe in code", apostrophe_in_code,
     False, "scripts/exemple.sh: typographic apostrophe U+2019")


def apostrophe_in_archive(work):
    path = work / "CHANGELOG.md"
    path.write_text(path.read_text(encoding="utf-8") + "\n" + chr(0x2019) + "\n", encoding="utf-8")


case("typographic apostrophe kept in an archive", apostrophe_in_archive, True)

if failures:
    print("documentation integrity behavior: FAIL", file=sys.stderr)
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
print(f"documentation integrity behavior: PASS ({len(cases)} cases)")

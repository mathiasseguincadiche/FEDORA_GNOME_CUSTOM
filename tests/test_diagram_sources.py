#!/usr/bin/env python3
"""The committed diagrams are exactly what tools/diagrams produces, and pass its checks.

A hand-edited export, a source and an export that drift apart, or a palette
change that breaks WCAG contrast all fail here.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

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

if errors:
    print("diagram sources: FAIL", file=sys.stderr)
    print("\n".join("- " + e for e in errors), file=sys.stderr)
    sys.exit(1)
print(f"diagram sources: PASS ({len(produced) // 2} pairs reproduced byte for byte, contrast and labels checked)")

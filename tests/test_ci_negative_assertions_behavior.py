#!/usr/bin/env python3
"""Exercise the actual CI exclusion helper and multimedia workflow block."""
import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts/ci/assert-absent.sh"


def workflow_run(path, step_name):
    """Read one literal run block without adding a YAML runtime dependency."""
    lines = path.read_text().splitlines()
    start = next(i for i, line in enumerate(lines)
                 if line.strip() == f"- name: {step_name}")
    run = next(i for i in range(start + 1, len(lines))
               if lines[i].strip() == "run: |")
    indent = len(lines[run]) - len(lines[run].lstrip())
    body = []
    for line in lines[run + 1:]:
        if line.strip() and len(line) - len(line.lstrip()) <= indent:
            break
        body.append(line)
    return textwrap.dedent("\n".join(body))


class ExclusionAssertions(unittest.TestCase):
    def invoke(self, *command):
        return subprocess.run(["bash", str(HELPER), *command],
                              capture_output=True, text=True, timeout=10)

    def test_match_fails_and_absence_succeeds(self):
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / "source"
            source.write_text("forbidden\n")
            self.assertEqual(self.invoke("grep", "-Fq", "forbidden", str(source)).returncode, 1)
            self.assertEqual(self.invoke("grep", "-Fq", "allowed", str(source)).returncode, 0)

    def test_unreadable_input_is_not_reported_absent(self):
        with tempfile.TemporaryDirectory() as temp:
            result = self.invoke("grep", "-Fq", "forbidden", str(Path(temp) / "missing"))
            self.assertEqual(result.returncode, 2)
            self.assertIn("could not be checked", result.stderr)

    def test_multimedia_step_fails_if_removed_provider_is_still_present(self):
        script = workflow_run(ROOT / ".github/workflows/fedora-package-preflight.yml",
                              "Validate multimedia provider swaps")
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            (directory / "dnf").write_text("#!/bin/sh\nexit 0\n")
            (directory / "rpm").write_text(
                '#!/bin/sh\nif [ "$2" = ffmpeg-free ]; then\n'
                '  exit "$TEST_FFMPEG_FREE_RC"\nfi\nexit 0\n')
            for command in ("rpm", "dnf"):
                (directory / command).chmod(0o755)
            for package_rc, expected in ((0, 1), (1, 0)):
                with self.subTest(ffmpeg_free_present=package_rc == 0):
                    env = dict(os.environ, PATH=str(directory) + ":" + os.environ["PATH"],
                               TEST_FFMPEG_FREE_RC=str(package_rc))
                    result = subprocess.run(["bash", "-e", "-o", "pipefail", "-c", script],
                                            cwd=ROOT, env=env, capture_output=True,
                                            text=True, timeout=10)
                    self.assertEqual(result.returncode, expected, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)

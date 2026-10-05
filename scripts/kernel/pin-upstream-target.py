#!/usr/bin/env python3
"""Bind DNF transactions to the exact reviewed upstream kernel RPM release.
Preserve unrelated administrator rules; reject overlapping external rules.
"""
import fnmatch
import os
import pathlib
import re
import stat
import sys
import tempfile
import tomllib

PACKAGES = ("kernel", "kernel-core", "kernel-modules", "kernel-modules-core", "kernel-modules-extra")
START = "# BEGIN FEDORA_GNOME_CUSTOM UPSTREAM TARGET"
END = "# END FEDORA_GNOME_CUSTOM UPSTREAM TARGET"


def render(text, release):
    if release != "--clear" and not re.fullmatch(r"[0-9]+[.][0-9]+(?:[.][0-9]+)?-[0-9.]+[.]vanilla[.]fc(?:44|45)[.]x86_64", release):
        raise ValueError("not a final upstream RPM target")
    if text.count(START) != text.count(END) or text.count(START) > 1:
        raise ValueError("invalid managed versionlock section")
    if START in text:
        start, end = text.index(START), text.index(END)
        if end < start:
            raise ValueError("invalid managed versionlock order")
        text = text[:start] + text[end + len(END):]
    data = tomllib.loads(text) if text.strip() else {"version": "1.0"}
    if data.get("version") != "1.0":
        raise ValueError("unsupported administrator versionlock format")
    if release == "--clear":
        return text.rstrip() + "\n" if text.strip() else 'version = "1.0"\n'
    for item in data.get("packages", []):
        name = item.get("name", "")
        if not isinstance(name, str) or any(fnmatch.fnmatchcase(pkg, name) for pkg in PACKAGES):
            raise ValueError("external kernel versionlock overlaps project target; review it explicitly")
    if not text.strip():
        text = 'version = "1.0"\n'
    evr = "0:" + release.rsplit(".", 1)[0]
    block = START + "\n"
    for name in PACKAGES:
        block += '\n[[packages]]\nname = "' + name + '"\ncomment = "Official upstream target; refreshed by project updater"\n'
        block += '[[packages.conditions]]\nkey = "evr"\ncomparator = "="\nvalue = "' + evr + '"\n'
        block += '[[packages.conditions]]\nkey = "arch"\ncomparator = "="\nvalue = "x86_64"\n'
    result = text.rstrip() + "\n\n" + block + END + "\n"
    tomllib.loads(result)
    return result


def main():
    if len(sys.argv) != 2 or os.geteuid() != 0:
        raise SystemExit("Run this helper through the guarded project kernel/update engine")
    path = pathlib.Path("/etc/dnf/versionlock.toml")
    if path.is_symlink() or path.exists() and not stat.S_ISREG(path.stat().st_mode):
        raise SystemExit("unsafe versionlock path")
    result = render(path.read_text() if path.exists() else "", sys.argv[1])
    fd, name = tempfile.mkstemp(prefix=".upstream-target-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as output:
            os.fchmod(output.fileno(), 0o644)
            output.write(result); output.flush(); os.fsync(output.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name): os.unlink(name)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError) as error:
        raise SystemExit(str(error))

#!/usr/bin/env python3
"""Verify the immutable upstream Gtk4-DING v148 manager; never patch files."""
import hashlib
from pathlib import Path
import sys
import zipfile

# Readiness artifact 14899232253 (run 45348084592); runtime run 45495888501.
ARCHIVE_SHA256 = "c695a52a8719209daa2c9e83e510e36618dbe201c357a58d8b2d6d5a5aadfd22"
MANAGER_SHA256 = "4c950afe935cde34e86c83cd4ed12ff30fcbdc19ec454930c0086523f9fd6d21"


def verify(directory):
    directory = Path(directory)
    manager = directory / "dingManager.js"
    if directory.is_symlink() or manager.is_symlink() or not manager.is_file():
        raise ValueError("Unsafe Gtk4-DING installed path")
    if hashlib.sha256(manager.read_bytes()).hexdigest() != MANAGER_SHA256:
        raise ValueError("Gtk4-DING upstream manager missing or modified")


def verify_archive(archive, directory):
    archive = Path(archive)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA256:
        raise ValueError("Unreviewed Gtk4-DING archive")
    with zipfile.ZipFile(archive) as source:
        if source.namelist().count("dingManager.js") != 1:
            raise ValueError("Ambiguous Gtk4-DING manager")
        if hashlib.sha256(source.read("dingManager.js")).hexdigest() != MANAGER_SHA256:
            raise ValueError("Gtk4-DING archive manager differs from reviewed source")
    verify(directory)


if __name__ == "__main__":
    try:
        if len(sys.argv) == 4 and sys.argv[1] == "verify-archive":
            verify_archive(sys.argv[2], sys.argv[3])
        elif len(sys.argv) == 3 and sys.argv[1] == "verify":
            verify(sys.argv[2])
        else:
            raise ValueError("Usage: verify-ding-source.py verify-archive ARCHIVE DIRECTORY | verify DIRECTORY")
        print("PASS: reviewed upstream Gtk4-DING v148 sha256=" + MANAGER_SHA256)
    except (ValueError, KeyError, OSError, zipfile.BadZipFile) as error:
        raise SystemExit(str(error))

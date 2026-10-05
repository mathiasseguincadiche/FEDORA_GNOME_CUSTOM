#!/usr/bin/env python3
"""Validate a reviewed release profile; pending/beta data never authorizes APPLY."""
import hashlib
import json
import pathlib
import re
import sys

PREFIXES = ("DING", "SHOW_DESKTOP_PLUS", "RESOURCE_MONITOR", "TILING_ASSISTANT")


def assignments(path):
    result = {}
    for line in path.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        match = re.fullmatch(r'([A-Z][A-Z0-9_]*)=(?:"([^"\n]*?)"|([A-Za-z0-9_./:@+-]+))', line)
        if not match or "$" in line or "`" in line or "\\" in line or match[1] in result:
            raise ValueError("unsafe or duplicate profile assignment")
        result[match[1]] = match[2] if match[2] is not None else match[3]
    return result


def validate(root, release):
    if release != 45:
        raise ValueError("only the reviewed Fedora 45 transition is supported")
    profile = json.loads((root / "profiles/fedora45/profile.json").read_text())
    if (profile.get("schema"), profile.get("release"), profile.get("gnome_major"), profile.get("status")) != (1, 45, 51, "ready"):
        raise ValueError("Fedora 45 profile is pending; final media/extensions/CI not promoted")
    media_path = root / "installer/fedora45-media.lock"
    extensions_path = root / "profiles/fedora45/gnome-extensions.lock"
    packages_path = root / "profiles/fedora45/packages-nautilus.txt"
    if hashlib.sha256(packages_path.read_bytes()).hexdigest() != profile.get("packages_lock_sha256"):
        raise ValueError("reviewed Fedora 45 package manifest digest mismatch")
    for key, path in (("media_lock_sha256", media_path), ("extensions_lock_sha256", extensions_path)):
        if hashlib.sha256(path.read_bytes()).hexdigest() != profile.get(key):
            raise ValueError("reviewed profile digest mismatch: " + key)
    media = assignments(media_path)
    expected_keys = set(assignments(root / "installer/fedora44-media.lock"))
    if set(media) != expected_keys:
        raise ValueError("media lock contains unknown or missing keys")
    compose = media.get("FEDORA_COMPOSE", "")
    if not re.fullmatch(r"[0-9]+[.][0-9]+", compose):
        raise ValueError("missing final compose")
    if media.get("ISO_FILENAME") != "Fedora-Workstation-Live-45-" + compose + ".x86_64.iso":
        raise ValueError("media name/compose mismatch")
    if media.get("CHECKSUM_FILENAME") != "Fedora-Workstation-45-" + compose + "-x86_64-CHECKSUM":
        raise ValueError("CHECKSUM name/compose mismatch")
    if not media.get("SOURCE_URL", "").startswith(("https://fedoraproject.org/", "https://download.fedoraproject.org/")):
        raise ValueError("unapproved Fedora source")
    if not re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+Z", media.get("VERIFIED_UTC", "")):
        raise ValueError("media verification date missing")
    if media.get("FEDORA_RELEASE") != "45" or media.get("RELEASE_STATUS") != "final":
        raise ValueError("a Fedora 45 final media lock is required")
    if not re.fullmatch(r"Fedora-Workstation-Live-45-[0-9]+\.[0-9]+\.x86_64\.iso", media.get("ISO_FILENAME", "")):
        raise ValueError("invalid final Workstation image name")
    if not re.fullmatch(r"[0-9a-f]{64}", media.get("ISO_SHA256", "")):
        raise ValueError("missing final media identity")
    if media.get("SIGNING_FINGERPRINT") != "4F50A6114CD5C6976A7F1179655A4B02F577861E":
        raise ValueError("Fedora 45 signing key is not pinned")
    lock = assignments(extensions_path)
    canonical = assignments(root / "config/gnome-extensions.lock")
    if set(lock) != set(canonical):
        raise ValueError("extension lock contains unknown or missing keys")
    for prefix in PREFIXES:
        for suffix in ("UUID", "SCHEMA"):
            key = prefix + "_" + suffix
            if key in canonical and lock[key] != canonical[key]:
                raise ValueError("extension identity changed: " + key)
        if lock.get(prefix + "_SHELL_VERSION") != "51":
            raise ValueError("unported GNOME extension: " + prefix)
        if not re.fullmatch(r"[0-9a-f]{64}", lock.get(prefix + "_SHA256", "")):
            raise ValueError("missing extension digest")
        if not re.fullmatch(r"[1-9][0-9]*", lock.get(prefix + "_VERSION", "")):
            raise ValueError("extension version missing")
        if prefix != "TILING_ASSISTANT":
            review = lock.get(prefix + "_REVIEW_ID", "")
            if not re.fullmatch(r"[1-9][0-9]*", review) or lock[prefix + "_SOURCE_URL"] != "https://extensions.gnome.org/review/download/" + review + ".shell-extension.zip":
                raise ValueError("extension URL/review mismatch")
        if not lock.get(prefix + "_SOURCE_URL", "").startswith(("https://extensions.gnome.org/review/download/", "https://github.com/Leleat/Tiling-Assistant/releases/download/")):
            raise ValueError("unreviewed extension source")
    if not re.fullmatch(r"[0-9a-f]{40}", profile.get("qualification_commit", "")):
        raise ValueError("missing qualification commit")
    return profile


if __name__ == "__main__":
    if len(sys.argv) != 4 or sys.argv[1] != "validate":
        raise SystemExit("Usage: fedora-profile.py validate REPO_ROOT 45")
    try:
        validate(pathlib.Path(sys.argv[2]), int(sys.argv[3]))
    except (ValueError, KeyError, FileNotFoundError) as error:
        raise SystemExit(str(error))

#!/usr/bin/env python3
"""Promote the Fedora 45 profile from the final, signed Workstation media.

Verifies the ISO against the signed CHECKSUM with the pinned Fedora 45 key, then writes
installer/fedora45-media.lock and profiles/fedora45/profile.json (status "ready") with the real
digests, and runs the same validator that every guard uses. On any failure the two files are
restored. promotion_source_commit identifies code examined BEFORE changing the locks. It does not attest a CI result for the resulting commit, does not commit, push or certify hardware.
"""
import argparse
import datetime
import hashlib
import importlib.util
import json
import pathlib
import re
import subprocess
import sys
import tempfile

ISO_RE = re.compile(r"Fedora-Workstation-Live-45-([0-9]+[.][0-9]+)[.]x86_64[.]iso")
COMMIT_RE = re.compile(r"[0-9a-f]{40}")
MEDIA_KEYS = ("FEDORA_RELEASE", "FEDORA_COMPOSE", "ISO_FILENAME", "ISO_SHA256", "CHECKSUM_FILENAME",
              "SOURCE_URL", "VERIFIED_UTC", "RELEASE_STATUS", "SIGNING_FINGERPRINT")


def load_validator(root):
    spec = importlib.util.spec_from_file_location("fedora_profile", root / "scripts/development/fedora-profile.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_signed_checksum(checksum, keyring, fingerprint, iso_name, iso_digest):
    with tempfile.TemporaryDirectory() as work:
        out = pathlib.Path(work) / "signed.txt"
        result = subprocess.run(["gpgv", "--status-fd", "1", "--keyring", str(keyring),
                                 "--output", str(out), str(checksum)],
                                capture_output=True, text=True, check=False)
        if result.returncode != 0 or not out.exists():
            raise ValueError("CHECKSUM signature is not valid for this keyring")
        valid = [line.split() for line in result.stdout.splitlines() if line.startswith("[GNUPG:] VALIDSIG ")]
        # A signing subkey is accepted only when its primary key is the pinned identity.
        if not any(row[2] == fingerprint or row[-1] == fingerprint for row in valid):
            raise ValueError("CHECKSUM is not signed by the pinned Fedora 45 key")
        pattern = re.compile(r"SHA256 \(" + re.escape(iso_name) + r"\) = ([0-9a-f]{64})")
        rows = [m.group(1) for m in (pattern.fullmatch(line) for line in out.read_text().splitlines()) if m]
        if rows != [iso_digest]:
            raise ValueError("signed CHECKSUM must bind the exact ISO name to the exact ISO hash")


def clean_tree(root):
    status = subprocess.run(["git", "-C", str(root), "status", "--porcelain"],
                            capture_output=True, text=True, check=False)
    if status.returncode != 0:
        raise ValueError("the repository root is not a Git checkout")
    if status.stdout.strip():
        raise ValueError("working tree is not clean; commit or stash first (the qualification commit must be exact)")


def promote(root, iso, checksum, keyring, commit, now=None):
    root = pathlib.Path(root)
    iso, checksum, keyring = map(pathlib.Path, (iso, checksum, keyring))
    if not COMMIT_RE.fullmatch(commit):
        raise ValueError("--commit must be a full 40-character lowercase Git SHA")
    match = ISO_RE.fullmatch(iso.name)
    if not match:
        raise ValueError("not a final Fedora 45 Workstation Live image name (Beta/RC names are refused): " + iso.name)
    compose = match.group(1)
    if checksum.name != "Fedora-Workstation-45-" + compose + "-x86_64-CHECKSUM":
        raise ValueError("CHECKSUM file name does not match the ISO compose: " + checksum.name)
    for path in (iso, checksum, keyring):
        if not path.is_file():
            raise ValueError("missing file: " + str(path))
    clean_tree(root)
    if subprocess.run(["git", "-C", str(root), "rev-parse", "HEAD"], capture_output=True, text=True,
                      check=False).stdout.strip() != commit:
        raise ValueError("--commit must be the current HEAD, the exact commit the CI evidence ran on")

    profile_path = root / "profiles/fedora45/profile.json"
    media_path = root / "installer/fedora45-media.lock"
    extensions_path = root / "profiles/fedora45/gnome-extensions.lock"
    packages_path = root / "profiles/fedora45/packages-nautilus.txt"
    current = json.loads(profile_path.read_text())
    fingerprint = current.get("signing_fingerprint", "")
    if not re.fullmatch(r"[0-9A-F]{40}", fingerprint):
        raise ValueError("profile.json has no pinned signing fingerprint")

    digest = sha256_file(iso)
    verify_signed_checksum(checksum, keyring, fingerprint, iso.name, digest)

    stamp = (now or datetime.datetime.now(datetime.timezone.utc)).strftime("%Y-%m-%dT%H:%M:%SZ")
    values = {
        "FEDORA_RELEASE": "45", "FEDORA_COMPOSE": compose, "ISO_FILENAME": iso.name, "ISO_SHA256": digest,
        "CHECKSUM_FILENAME": checksum.name, "SOURCE_URL": "https://fedoraproject.org/workstation/download/",
        "VERIFIED_UTC": stamp, "RELEASE_STATUS": "final", "SIGNING_FINGERPRINT": fingerprint,
    }
    previous = {path: (path.read_bytes() if path.exists() else None) for path in (media_path, profile_path)}
    try:
        media_path.write_text("# Fedora Workstation 45 x86_64 installation-media lock.\n"
                              "# Written by scripts/development/promote-fedora45.py after a signed-CHECKSUM verification.\n"
                              + "".join(key + "=" + values[key] + "\n" for key in MEDIA_KEYS))
        profile = {
            "schema": 1, "release": 45, "gnome_major": 51, "status": "ready",
            "signing_fingerprint": fingerprint,
            "media_lock_sha256": sha256_file(media_path),
            "extensions_lock_sha256": sha256_file(extensions_path),
            "packages_lock_sha256": sha256_file(packages_path),
            # This SHA predates the new media lock: it is NOT CI evidence on the promoted tree.
            "promotion_source_commit": commit,
        }
        profile_path.write_text(json.dumps(profile, indent=2) + "\n")
        load_validator(root).validate(root, 45)
    except Exception:
        for path, data in previous.items():
            if data is None:
                path.unlink(missing_ok=True)
            else:
                path.write_bytes(data)
        raise
    return profile


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--iso", required=True)
    parser.add_argument("--checksum", required=True)
    parser.add_argument("--keyring", required=True, help="GPG keyring holding the Fedora 45 key")
    parser.add_argument("--commit", required=True, help="current HEAD: the commit the CI evidence ran on")
    parser.add_argument("--root", default=str(pathlib.Path(__file__).resolve().parents[2]))
    args = parser.parse_args()
    try:
        profile = promote(args.root, args.iso, args.checksum, args.keyring, args.commit)
    except (ValueError, OSError, KeyError) as error:
        print("PROMOTION REFUSED: " + str(error), file=sys.stderr)
        return 1
    print("Fedora 45 profile promoted: status=ready promotion_source_commit=" + profile["promotion_source_commit"])
    print("Review `git diff`, commit installer/fedora45-media.lock and profiles/fedora45/profile.json, "
          "and let the CI run on that commit.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

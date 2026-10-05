#!/usr/bin/env python3
"""Resolve the image filename from a signed CHECKSUM and independently pinned hash."""
import json
import os
import pathlib
import re
import shlex
import subprocess
import urllib.request


def image_from_checksum(text, expected_sha):
    matches = re.findall(r"^SHA256 \(([^/()]+\.x86_64\.qcow2)\) = " +
                         re.escape(expected_sha) + r"$", text, re.M)
    if len(matches) != 1 or not matches[0].startswith("Fedora-Cloud-Base-Generic-45_Beta-1.3"):
        raise ValueError("Signed filename/hash pair is not the expected Fedora 45 Beta cloud image")
    return matches[0]


def download(url, target):
    with urllib.request.urlopen(url, timeout=60) as response:
        if not response.url.startswith("https://"):
            raise ValueError("HTTPS required")
        target.write_bytes(response.read())


def main():
    if os.environ.get("GITHUB_ACTIONS") != "true":
        raise SystemExit("Disposable GitHub runner required")
    root = pathlib.Path(os.environ["GITHUB_WORKSPACE"])
    config = json.loads((root / ".github/fedora45-preview-media.json").read_text())
    work = root / ".fedora45-preview"
    work.mkdir(mode=0o700, exist_ok=False)
    keyring = work / "gnupg"
    keyring.mkdir(mode=0o700)
    download("https://fedoraproject.org/fedora.pgp", work / "fedora.pgp")
    download(config["url"] + "/" + config["checksum"], work / "checksum")
    subprocess.run(["gpg", "--homedir", str(keyring), "--batch", "--import",
                    str(work / "fedora.pgp")], check=True)
    exported = subprocess.check_output(["gpg", "--homedir", str(keyring), "--batch",
                                       "--export", config["signing_fingerprint"]])
    if not exported:
        raise ValueError("Pinned Fedora 45 key missing")
    (work / "fedora45.gpg").write_bytes(exported)
    verify = subprocess.run(["gpgv", "--keyring", str(work / "fedora45.gpg"),
                             "--status-fd", "2", "--output", str(work / "signed.txt"),
                             str(work / "checksum")], capture_output=True, check=True)
    status = verify.stderr.decode()
    (work / "signature.log").write_text(status)
    if "[GNUPG:] VALIDSIG " + config["signing_fingerprint"] + " " not in status:
        raise ValueError("Unexpected signing key")
    image = image_from_checksum((work / "signed.txt").read_text(), config["image_sha256"])
    values = dict(FEDORA_CLOUD_IMAGE=image, FEDORA_CLOUD_SHA256=config["image_sha256"],
                  FEDORA_CLOUD_CHECKSUM=config["checksum"], FEDORA_CLOUD_URL=config["url"],
                  FEDORA_SIGNING_FINGERPRINT=config["signing_fingerprint"])
    (work / "fedora45-cloud.lock").write_text("".join(
        key + "=" + shlex.quote(value) + "\n" for key, value in values.items()))
    print("PASS: signed preview image/hash identity; not a production media promotion")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
import importlib.util
import pathlib
root = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("preview", root / ".github/scripts/fedora45-preview-media.py")
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)
sha = "a" * 64
name = "Fedora-Cloud-Base-Generic-45_Beta-1.3.x86_64.qcow2"
assert preview.image_from_checksum("SHA256 (" + name + ") = " + sha + "\n", sha) == name
for text in ("", "SHA256 (" + name + ") = " + "b" * 64,
             "SHA256 (../" + name + ") = " + sha,
             "SHA256 (Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2) = " + sha,
             ("SHA256 (" + name + ") = " + sha + "\n") * 2):
    try:
        preview.image_from_checksum(text, sha)
    except ValueError:
        pass
    else:
        raise AssertionError("Wrong or ambiguous image identity accepted")
print("Signed preview filename/hash negative cases: PASS")

#!/usr/bin/env python3
"""Inspect downloaded GNOME artifacts and the real target Fedora packages.
Candidate output never promotes the production profile or certifies hardware.
"""
import argparse
import hashlib
import importlib.util
import io
import json
import pathlib
import re
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("profile", ROOT / "scripts/development/fedora-profile.py")
profile = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profile)


def fetch(url):
    if not url.startswith(("https://extensions.gnome.org/", "https://api.github.com/",
                           "https://github.com/Leleat/", "https://copr.fedorainfracloud.org/")):
        raise ValueError("unapproved source URL")
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "FEDORA_GNOME_CUSTOM-readiness"}), timeout=30) as response:
        if not response.url.startswith("https://"):
            raise ValueError("insecure redirect")
        data = response.read(32 * 1024 * 1024 + 1)
        if len(data) > 32 * 1024 * 1024:
            raise ValueError("artifact too large")
        return data


def inspect_zip(data, uuid, shell):
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        names = archive.namelist()
        if names.count("metadata.json") != 1:
            raise ValueError("missing or duplicate metadata")
        if any(pathlib.PurePosixPath(n).is_absolute() or ".." in pathlib.PurePosixPath(n).parts for n in names):
            raise ValueError("unsafe archive path")
        if sum(info.file_size for info in archive.infolist()) > 64 * 1024 * 1024:
            raise ValueError("expanded archive too large")
        metadata = json.loads(archive.read("metadata.json"))
        if metadata.get("uuid") != uuid or str(shell) not in [str(s) for s in metadata.get("shell-version", [])]:
            raise ValueError("downloaded metadata does not match UUID/GNOME")
        if not any(n.startswith("schemas/") and n.endswith(".gschema.xml") for n in names):
            raise ValueError("extension schemas missing")
    return hashlib.sha256(data).hexdigest()


def ego_candidate(uuid, shell, transport=fetch):
    query = urllib.parse.urlencode({"uuid": uuid, "shell_version": shell})
    answer = json.loads(transport("https://extensions.gnome.org/extension-info/?" + query))
    version, tag = str(answer.get("version", "")), str(answer.get("version_tag", ""))
    if not version.isdigit() or not tag.isdigit():
        raise ValueError("no reviewed candidate for target GNOME")
    url = "https://extensions.gnome.org/review/download/" + tag + ".shell-extension.zip"
    digest = inspect_zip(transport(url), uuid, shell)
    return {"SOURCE_URL": url, "REVIEW_ID": tag, "VERSION": version,
            "SHELL_VERSION": str(shell), "SHA256": digest}


def tiling_candidate(uuid, shell, transport=fetch):
    answer = json.loads(transport("https://api.github.com/repos/Leleat/Tiling-Assistant/releases/latest"))
    tag = answer.get("tag_name", "")
    if not re.fullmatch(r"v[0-9]+", tag) or answer.get("prerelease") or answer.get("draft"):
        raise ValueError("no final Tiling Assistant release")
    name = uuid + ".shell-extension.zip"
    assets = [a["browser_download_url"] for a in answer.get("assets", []) if a.get("name") == name]
    if len(assets) != 1 or not assets[0].startswith("https://github.com/Leleat/Tiling-Assistant/releases/download/" + tag + "/"):
        raise ValueError("unexpected Tiling Assistant asset")
    digest = inspect_zip(transport(assets[0]), uuid, shell)
    return {"SOURCE_URL": assets[0], "VERSION": tag[1:],
            "SHELL_VERSION": str(shell), "SHA256": digest}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fedora", type=int, default=45)
    parser.add_argument("--shell", type=int, default=51)
    parser.add_argument("--pin", action="store_true", help="print candidate pins after actual archive inspection")
    parser.add_argument("--report-only", action="store_true", help="collect blockers, exit zero; never means qualified")
    parser.add_argument("--output", type=pathlib.Path)
    args = parser.parse_args()
    if (args.fedora, args.shell) != (45, 51):
        parser.error("only Fedora 45 / GNOME 51 is supported")
    entries = []
    lock = profile.assignments(ROOT / "config/gnome-extensions.lock")
    candidate = dict(lock)

    def check(component, action):
        try:
            detail = action()
            entries.append({"component": component, "status": "READY", "detail": str(detail)})
        except (ValueError, KeyError, OSError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
            entries.append({"component": component, "status": "BLOCKED", "detail": str(error)})

    def extension(prefix):
        uuid = lock[prefix + "_UUID"]
        result = (tiling_candidate if prefix == "TILING_ASSISTANT" else ego_candidate)(uuid, args.shell)
        candidate.update({prefix + "_" + key: value for key, value in result.items()})
        return "downloaded UUID/GNOME metadata and SHA256 verified"

    for prefix in profile.PREFIXES:
        check(prefix, lambda prefix=prefix: extension(prefix))

    def packages():
        if not shutil.which("dnf5"):
            raise ValueError("target Fedora package checks unavailable; skipped work is BLOCKED")
        actual = subprocess.check_output(["rpm", "-E", "%fedora"], text=True).strip()
        if actual != str(args.fedora):
            raise ValueError("must inspect packages inside actual Fedora 45")
        paths = sorted(ROOT.glob("manifests/packages-*.txt"))
        names = sorted({line.strip() for path in paths for line in path.read_text().splitlines()
                        if line.strip() and not line.lstrip().startswith("#")})
        missing = []
        for name in names:
            found = subprocess.run(["dnf5", "-q", "repoquery", "--available", "--qf", "%{NAME}", name],
                                   capture_output=True, text=True, check=False)
            if found.returncode or not found.stdout.strip():
                missing.append(name)
        if missing:
            raise ValueError("unresolved target packages: " + ", ".join(missing))
        return str(len(names)) + " Fedora/RPMFusion packages resolved"
    check("Fedora45 packages", packages)

    def rpm_extensions():
        for uuid in ("dash-to-dock@micxgx.gmail.com", "appindicatorsupport@rgcjonas.gmail.com"):
            metadata = json.loads((pathlib.Path("/usr/share/gnome-shell/extensions") / uuid / "metadata.json").read_text())
            if metadata.get("uuid") != uuid or "51" not in [str(v) for v in metadata.get("shell-version", [])]:
                raise ValueError("installed RPM extension incompatible with GNOME 51: " + uuid)
        return "installed RPM extension metadata compatible"
    check("GNOME51 RPM extensions", rpm_extensions)

    def kernel():
        sys.path.insert(0, str(ROOT / "scripts/kernel"))
        from importlib import import_module
        upstream = import_module("upstream-release").fetch_release()
        if not shutil.which("dnf5"):
            raise ValueError("no actual upstream RPM query available")
        result = subprocess.check_output(["dnf5", "-q", "--refresh",
            "--repo=*group_kernel-vanilla:stable", "--repo=*group_kernel-vanilla:fedora",
            "repoquery", "--available", "--qf", "%{VERSION}-%{RELEASE}.%{ARCH}", "kernel-core"], text=True)
        if not any(re.fullmatch(re.escape(upstream) + r"-[0-9.]+[.]vanilla[.]fc45[.]x86_64", v) for v in result.splitlines()):
            raise ValueError("latest kernel.org stable RPM not available for Fedora 45")
        return "actual upstream RPM = kernel.org " + upstream
    check("Upstream Linux45", kernel)
    check("Final production profile", lambda: profile.validate(ROOT, 45)["qualification_commit"])
    blocked = any(x["status"] != "READY" for x in entries)
    report = {"schema": 1, "fedora": 45, "gnome": 51, "status": "BLOCKED" if blocked else "READY",
              "scope": "readiness-only; no production promotion or hardware certification",
              "report_only": args.report_only, "checks": entries}
    for item in entries:
        print(item["status"], item["component"], item["detail"], sep="\t")
    print("OVERALL=" + report["status"] + " REPORT_ONLY=" + str(args.report_only).lower())
    all_extensions = all(x["status"] == "READY" for x in entries[:4])
    pins = "# CANDIDATE ONLY: metadata checked; review and runtime qualification still required.\n"
    pins += "".join(key + '="' + value + '"\n' for key, value in candidate.items())
    if args.output:
        args.output.mkdir(parents=True, exist_ok=True)
        (args.output / "readiness.json").write_text(json.dumps(report, indent=2) + "\n")
        if all_extensions:
            (args.output / "candidate-gnome-extensions.lock").write_text(pins)
    if args.pin and all_extensions:
        print(pins, end="")
    return 0 if args.report_only or not blocked else 1


if __name__ == "__main__":
    raise SystemExit(main())

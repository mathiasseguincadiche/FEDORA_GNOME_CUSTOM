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
import xml.etree.ElementTree as ET
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("profile", ROOT / "scripts/development/fedora-profile.py")
profile = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profile)


def fetch(url):
    if not url.lower().startswith(("https://extensions.gnome.org/", "https://api.github.com/",
                           "https://github.com/leleat/", "https://github.com/ubuntu/tiling-assistant/", "https://copr.fedorainfracloud.org/")):
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
    answer = json.loads(transport("https://api.github.com/repos/ubuntu/Tiling-Assistant/releases/latest"))
    tag = answer.get("tag_name", "")
    if not re.fullmatch(r"v[0-9]+", tag) or answer.get("prerelease") or answer.get("draft"):
        raise ValueError("no final Tiling Assistant release")
    name = uuid + ".shell-extension.zip"
    assets = [a["browser_download_url"] for a in answer.get("assets", []) if a.get("name") == name]
    if len(assets) != 1 or not assets[0].lower().startswith("https://github.com/ubuntu/tiling-assistant/releases/download/" + tag.lower() + "/"):
        raise ValueError("unexpected Tiling Assistant release asset")
    digest = inspect_zip(transport(assets[0]), uuid, shell)
    return {"SOURCE_URL": assets[0], "VERSION": tag[1:],
            "SHELL_VERSION": str(shell), "SHA256": digest}


# Informational probes (EGO numeric ids). They never change READY/BLOCKED and never write a lock.
# The original DING has no GNOME 51 build yet; report it so a native build is noticed.
PROBES = (("DING (rastersoft) native GNOME 51 build", 2087),)


def probe_candidate(pk, shell, transport=fetch):
    query = urllib.parse.urlencode({"pk": pk, "shell_version": shell})
    answer = json.loads(transport("https://extensions.gnome.org/extension-info/?" + query))
    uuid, tag = str(answer.get("uuid", "")), str(answer.get("version_tag", ""))
    if not uuid or not tag.isdigit():
        raise ValueError("no build offered for GNOME " + str(shell))
    url = "https://extensions.gnome.org/review/download/" + tag + ".shell-extension.zip"
    data = transport(url)
    digest = inspect_zip(data, uuid, shell)
    schemas, enums = {}, {}
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        metadata = json.loads(archive.read("metadata.json"))
        for name in archive.namelist():
            if name.startswith("schemas/") and name.endswith(".gschema.xml"):
                root = ET.fromstring(archive.read(name))
                for node in root.iter("enum"):
                    enums[node.get("id")] = [value.get("nick") + "=" + value.get("value")
                                             for value in node.iter("value")]
                for node in root.iter("schema"):
                    schemas[node.get("id")] = {
                        key.get("name"): (key.get("type") or "enum:" + str(key.get("enum")))
                        + " default=" + (key.findtext("default") or "").strip()
                        for key in node.iter("key")}
    return {"name": answer.get("name"), "uuid": uuid, "version": answer.get("version"),
            "review_id": tag, "source_url": url, "sha256": digest,
            "shell_versions": metadata.get("shell-version"), "schemas": schemas, "enums": enums}


def pinned_check(prefix, pins, shell, transport=fetch):
    """Download the exact pinned archive and prove URL, digest, UUID and GNOME major still hold."""
    url = pins[prefix + "_SOURCE_URL"]
    data = transport(url)
    digest = inspect_zip(data, pins[prefix + "_UUID"], shell)
    if digest != pins[prefix + "_SHA256"]:
        raise ValueError("pinned archive digest changed: " + digest)
    schema = pins.get(prefix + "_SCHEMA", "")
    if schema:
        # scripts/gnome/install-pinned-extension.sh refuses an archive without this exact file.
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            if "schemas/" + schema + ".gschema.xml" not in archive.namelist():
                raise ValueError("installer expects schemas/" + schema + ".gschema.xml in the archive")
    return "pinned archive downloaded; UUID/GNOME " + str(shell) + " metadata and SHA256 verified"


def latest_status(prefix, pins, shell, transport=fetch):
    """Compare the pinned archive with the newest build published for this GNOME major.

    Returns (status, detail, candidate) where status is UP-TO-DATE, NEWER or UNKNOWN and candidate
    holds the pin fields of the newest build (empty when it cannot be inspected).
    """
    uuid = pins[prefix + "_UUID"]
    try:
        fetch_latest = tiling_candidate if prefix == "TILING_ASSISTANT" else ego_candidate
        latest = fetch_latest(uuid, shell, transport)
    except (ValueError, KeyError, OSError, zipfile.BadZipFile) as error:
        return "UNKNOWN", "newest build could not be inspected: " + str(error), {}
    if latest["SHA256"] == pins[prefix + "_SHA256"]:
        return "UP-TO-DATE", "pinned v" + pins[prefix + "_VERSION"] + " is the newest build", latest
    detail = "pinned v" + pins[prefix + "_VERSION"] + " -> available v" + latest["VERSION"]
    if "REVIEW_ID" in latest:
        detail += " (review " + latest["REVIEW_ID"] + ")"
    return "NEWER", detail + " sha256=" + latest["SHA256"], latest


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fedora", type=int, default=45)
    parser.add_argument("--shell", type=int, default=51)
    parser.add_argument("--pin", action="store_true", help="print candidate pins after actual archive inspection")
    parser.add_argument("--report-only", action="store_true", help="collect blockers, exit zero; never means qualified")
    parser.add_argument("--latest", action="store_true",
                        help="also compare every pin with the newest published build (release-day check)")
    parser.add_argument("--output", type=pathlib.Path)
    args = parser.parse_args()
    if (args.fedora, args.shell) != (45, 51):
        parser.error("only Fedora 45 / GNOME 51 is supported")
    entries = []
    profile_lock = ROOT / "profiles/fedora45/gnome-extensions.lock"
    lock = profile.assignments(profile_lock if profile_lock.exists() else ROOT / "config/gnome-extensions.lock")
    candidate = dict(lock)
    found_prefixes = []
    kernel_seen = []

    def check(component, action):
        try:
            detail = action()
            entries.append({"component": component, "status": "READY", "detail": str(detail)})
        except (ValueError, KeyError, OSError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
            entries.append({"component": component, "status": "BLOCKED", "detail": str(error)})

    def extension(prefix):
        if profile_lock.exists():
            return pinned_check(prefix, lock, args.shell)
        uuid = lock[prefix + "_UUID"]
        result = (tiling_candidate if prefix == "TILING_ASSISTANT" else ego_candidate)(uuid, args.shell)
        candidate.update({prefix + "_" + key: value for key, value in result.items()})
        found_prefixes.append(prefix)
        return "downloaded UUID/GNOME metadata and SHA256 verified"

    for prefix in profile.PREFIXES:
        check(prefix, lambda prefix=prefix: extension(prefix))

    def packages():
        if not shutil.which("dnf5"):
            raise ValueError("target Fedora package checks unavailable; skipped work is BLOCKED")
        actual = subprocess.check_output(["rpm", "-E", "%fedora"], text=True).strip()
        if actual != str(args.fedora):
            raise ValueError("must inspect packages inside actual Fedora 45")
        paths = [p for p in sorted(ROOT.glob("manifests/packages-*.txt")) if p.name != "packages-nautilus.txt"]
        paths.append(ROOT / "profiles/fedora45/packages-nautilus.txt")
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
            "repoquery", "--available", "--qf", "%{VERSION}-%{RELEASE}.%{ARCH}\n", "kernel-core"], text=True)
        if not any(re.fullmatch(re.escape(upstream) + (r"(?:[.]0)?" if upstream.count(".") == 1 else "") + r"-[0-9.]+[.]vanilla[.]fc45[.]x86_64", v) for v in result.splitlines()):
            raise ValueError("kernel.org=" + upstream + "; Fedora 45 RPM candidates=" + result.strip())
        kernel_seen.append(upstream)
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
    probes = []
    for label, pk in PROBES:
        try:
            found = probe_candidate(pk, args.shell)
        except (ValueError, KeyError, OSError, zipfile.BadZipFile, ET.ParseError) as error:
            found = {"unavailable": str(error)}
        probes.append({"candidate": label, "pk": pk, **found})
        print("PROBE", label, json.dumps(found, sort_keys=True), sep="\t")
    report["replacement_probes"] = probes
    if args.latest:
        newest = dict(lock)
        report["latest"] = []
        for prefix in profile.PREFIXES:
            status, detail, found = latest_status(prefix, lock, args.shell)
            report["latest"].append({"component": prefix, "status": status, "detail": detail})
            print("LATEST", prefix, status + " " + detail, sep="\t")
            if status == "NEWER":
                newest.update({prefix + "_" + key: value for key, value in found.items()})
        if kernel_seen:
            minimum = profile.assignments(ROOT / "config/kernel.conf").get("KERNEL_MIN_VERSION", "")
            note = "kernel.org stable " + kernel_seen[0] + " (configured floor " + (minimum or "unset") + ")"
            print("LATEST", "KERNEL", note, sep="\t")
            report["latest"].append({"component": "KERNEL", "status": "INFO", "detail": note})
        if any(item["status"] == "NEWER" for item in report["latest"]):
            newest_text = "# NEWER BUILDS FOUND: review each one, then replace the matching pins by hand.\n" + "".join(
                key + '="' + value + '"\n' for key, value in newest.items())
            if args.output:
                args.output.mkdir(parents=True, exist_ok=True)
                (args.output / "latest-gnome-extensions.lock").write_text(newest_text)
    for prefix in found_prefixes:
        print("CANDIDATE", prefix, json.dumps({k[len(prefix) + 1:]: v for k, v in candidate.items()
                                                if k.startswith(prefix + "_")}, sort_keys=True), sep="\t")
    blocked = any(x["status"] != "READY" for x in entries)
    report = {"schema": 1, "fedora": 45, "gnome": 51, "status": "BLOCKED" if blocked else "READY",
              "scope": "readiness-only; no production promotion or hardware certification",
              "report_only": args.report_only, "checks": entries}
    for item in entries:
        print(item["status"], item["component"], item["detail"], sep="\t")
    print("OVERALL=" + report["status"] + " REPORT_ONLY=" + str(args.report_only).lower())
    probes = []
    for label, pk in PROBES:
        try:
            found = probe_candidate(pk, args.shell)
        except (ValueError, KeyError, OSError, zipfile.BadZipFile, ET.ParseError) as error:
            found = {"unavailable": str(error)}
        probes.append({"candidate": label, "pk": pk, **found})
        print("PROBE", label, json.dumps(found, sort_keys=True), sep="\t")
    report["replacement_probes"] = probes
    for prefix in profile.PREFIXES:
        if (prefix + "_SOURCE_URL") in candidate and candidate[prefix + "_SOURCE_URL"] != lock.get(prefix + "_SOURCE_URL") or prefix == "TILING_ASSISTANT":
            print("CANDIDATE", prefix, json.dumps({k[len(prefix) + 1:]: v for k, v in candidate.items()
                                                    if k.startswith(prefix + "_")}, sort_keys=True), sep="\t")
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

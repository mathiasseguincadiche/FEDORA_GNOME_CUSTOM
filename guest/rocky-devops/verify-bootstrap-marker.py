#!/usr/bin/env python3
"""Validate Rocky DevOps bootstrap evidence without sourcing untrusted .env data."""
import argparse
from datetime import datetime, timezone
from pathlib import Path
import re
import sys

FIELDS = {"completed_at", "kubernetes_minor", "kubernetes_release", "kind_version",
          "minikube_version", "node_version", "java_version", "yq_version",
          "k9s_version", "rpm_release", "helm_version"}
SEMVER = re.compile(r"v[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.+-]+)?")

def verify(text: str, *, minor="v1.37", kind="v0.33.0", minikube="v1.38.1", os_release="10.2"):
    values = {}
    for line in text.splitlines():
        if "=" not in line:
            raise ValueError("invalid completion evidence line")
        key, value = line.split("=", 1)
        if key not in FIELDS or key in values or not value:
            raise ValueError("duplicate, unknown or empty field")
        if any(ord(ch) < 32 or ord(ch) == 127 for ch in value):
            raise ValueError("control character in marker")
        values[key] = value
    if set(values) != FIELDS:
        raise ValueError("incomplete completion evidence")
    if (values["kubernetes_minor"], values["kind_version"],
            values["minikube_version"], values["rpm_release"]) != (minor, kind, minikube, os_release):
        raise ValueError("stale Rocky release or toolchain versions")
    if not re.fullmatch(r"v[0-9]+\.[0-9]+", minor):
        raise ValueError("unrecognized Kubernetes minor")
    for key in ("kubernetes_release", "kind_version", "minikube_version",
                "node_version", "yq_version", "k9s_version", "helm_version"):
        if not SEMVER.fullmatch(values[key]):
            raise ValueError(f"invalid version field {key}")
    if not values["kubernetes_release"].startswith(minor + "."):
        raise ValueError("wrong Kubernetes patch release")
    if int(values["node_version"].split(".")[0][1:]) < 22:
        raise ValueError("Node.js 22+ required")
    if int(values["yq_version"].split(".")[0][1:]) != 4:
        raise ValueError("Go yq v4 required")
    if not re.fullmatch(r"javac 21(?:\.[0-9]+)*", values["java_version"]):
        raise ValueError("OpenJDK 21 required")
    try:
        timestamp = datetime.strptime(values["completed_at"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError as exc:
        raise ValueError("invalid UTC completion timestamp") from exc
    if timestamp > datetime.now(timezone.utc):
        raise ValueError("completion timestamp in the future")
    return values

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("marker", type=Path)
    parser.add_argument("--kubernetes-minor", default="v1.37")
    parser.add_argument("--kind-version", default="v0.33.0")
    parser.add_argument("--minikube-version", default="v1.38.1")
    parser.add_argument("--os-release", default="10.2")
    args = parser.parse_args(argv)
    try:
        if args.marker.is_symlink() or not args.marker.is_file():
            raise ValueError("marker is not a regular file")
        verify(args.marker.read_text(encoding="utf-8"),
               minor=args.kubernetes_minor, kind=args.kind_version,
               minikube=args.minikube_version, os_release=args.os_release)
    except (OSError, UnicodeError, ValueError) as exc:
        print(f"FAIL Rocky bootstrap evidence: {exc}", file=sys.stderr)
        return 1
    print("Rocky bootstrap marker: VALID (runtime verification separate)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

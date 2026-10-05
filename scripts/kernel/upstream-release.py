#!/usr/bin/env python3
"""Select the published upstream stable kernel; reject RC and ambiguous feeds."""
import argparse
import json
import re
import urllib.request


def latest_stable(payload):
    version = payload["latest_stable"]["version"]
    if not isinstance(version, str) or not re.fullmatch(r"[1-9][0-9]*\.[0-9]+(?:\.[0-9]+)?", version):
        raise ValueError("latest_stable is not a final Linux release")
    matches = [r for r in payload["releases"] if r.get("version") == version
               and r.get("moniker") in ("stable", "mainline") and r.get("iseol") is False]
    if len(matches) != 1:
        raise ValueError("published stable release missing or ambiguous")
    return version


def fetch_release():
    url = "https://www.kernel.org/releases.json"
    with urllib.request.urlopen(url, timeout=30) as response:
        if response.geturl() != url:
            raise ValueError("unexpected kernel.org redirect")
        return latest_stable(json.loads(response.read(1048576)))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.parse_args()
    print(fetch_release())

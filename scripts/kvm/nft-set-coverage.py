#!/usr/bin/env python3
"""Prove that every protected IPv4 CIDR is covered by the KVM guard nft set.

Reads `nft -j list set inet TABLE blocked_host_ipv4` on stdin. Coverage is an
address-range proof, not text matching: nft prints a /32 without its prefix
and the auto-merge set folds contained or adjacent networks together.
Prints each uncovered CIDR and exits 1 when one is missing.
"""
import ipaddress
import json
import sys


def element_ranges(element):
    """Yield (first, last) integer ranges for one nft set element."""
    if isinstance(element, dict) and "elem" in element:
        element = element["elem"].get("val")
    if isinstance(element, str):
        address = int(ipaddress.IPv4Address(element))
        yield address, address
    elif isinstance(element, dict) and "prefix" in element:
        network = ipaddress.IPv4Network(
            f"{element['prefix']['addr']}/{element['prefix']['len']}", strict=False)
        yield int(network.network_address), int(network.broadcast_address)
    elif isinstance(element, dict) and "range" in element:
        first, last = element["range"]
        yield int(ipaddress.IPv4Address(first)), int(ipaddress.IPv4Address(last))
    else:
        raise ValueError(f"unsupported nft set element: {element!r}")


def covered(network, ranges):
    """True when the union of the sorted ranges contains the whole network."""
    start, end = int(network.network_address), int(network.broadcast_address)
    for first, last in sorted(ranges):
        if first > start:
            return False
        if last >= start:
            start = last + 1
            if start > end:
                return True
    return False


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: nft-set-coverage.py CIDR[,CIDR...] < nft-set.json")
    document = json.load(sys.stdin)
    ranges = []
    for item in document.get("nftables", []):
        for element in (item.get("set") or {}).get("elem", []):
            ranges.extend(element_ranges(element))
    missing = [cidr for cidr in filter(None, sys.argv[1].split(","))
               if not covered(ipaddress.IPv4Network(cidr, strict=False), ranges)]
    for cidr in missing:
        print(cidr)
    return 1 if missing else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, KeyError, TypeError, json.JSONDecodeError) as error:
        print(f"invalid nft set: {error}", file=sys.stderr)
        sys.exit(2)

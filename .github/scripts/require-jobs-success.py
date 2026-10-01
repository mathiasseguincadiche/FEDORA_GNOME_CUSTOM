#!/usr/bin/env python3
"""A required check must fail when a dependency failed, skipped or was cancelled."""
import json
import sys


def successful(payload, required):
    return set(payload) == set(required) and all(
        payload[name].get("result") == "success" for name in required)


if __name__ == "__main__":
    needs = json.load(sys.stdin)
    if not successful(needs, sys.argv[1:]):
        print("Required job dependencies did not all succeed: " +
              json.dumps(needs, sort_keys=True), file=sys.stderr)
        sys.exit(1)

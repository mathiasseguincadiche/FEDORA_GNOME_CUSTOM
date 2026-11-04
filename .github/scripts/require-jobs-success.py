#!/usr/bin/env python3
"""A required check must fail when a dependency failed, skipped or was cancelled.

One exception: with --docs-only-skippable, the listed jobs may be skipped when
the `changes` job itself succeeded and reported a documentation-only pull
request. Every other job must still succeed, and `changes` must be required.

Usage: require-jobs-success.py [--docs-only-skippable job,job] job... < needs.json
"""
import json
import sys


def docs_only(payload):
    changes = payload.get("changes") or {}
    return changes.get("result") == "success" and (changes.get("outputs") or {}).get("docs_only") == "true"


def successful(payload, required, skippable=()):
    if set(payload) != set(required) or (skippable and "changes" not in required):
        return False
    allowed = set(skippable) if docs_only(payload) else set()
    return all(payload[name].get("result") == "success" or
               (name in allowed and payload[name].get("result") == "skipped")
               for name in required)


def parse(argv):
    skippable = []
    if len(argv) > 2 and argv[1] == "--docs-only-skippable":
        skippable = [name for name in argv[2].split(",") if name]
        argv = argv[:1] + argv[3:]
    return argv[1:], skippable


if __name__ == "__main__":
    required, skippable = parse(sys.argv)
    needs = json.load(sys.stdin)
    if not successful(needs, required, skippable):
        print("Required job dependencies did not all succeed: " +
              json.dumps(needs, sort_keys=True), file=sys.stderr)
        sys.exit(1)
    if docs_only(needs) and skippable:
        print("Documentation-only pull request: skipped " +
              ", ".join(name for name in skippable if needs[name].get("result") == "skipped"))

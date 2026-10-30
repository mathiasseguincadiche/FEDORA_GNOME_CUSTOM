#!/usr/bin/env python3
"""KVM guard coverage proof on nft JSON set listings (libnftables-json(5))."""
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts/kvm/nft-set-coverage.py"


def listing(*elements):
    return json.dumps({"nftables": [
        {"metainfo": {"version": "1.1.1", "json_schema_version": 1}},
        {"set": {"family": "inet", "name": "blocked_host_ipv4", "table": "fedora_gnome_custom_kvm",
                 "type": "ipv4_addr", "flags": ["interval"], "elem": list(elements)}}]})


def prefix(addr, length):
    return {"prefix": {"addr": addr, "len": length}}


class GuardCoverage(unittest.TestCase):
    def check(self, protected, document):
        return subprocess.run([sys.executable, str(HELPER), protected], input=document,
                              text=True, capture_output=True, timeout=10)

    def assert_covered(self, protected, document):
        result = self.check(protected, document)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def assert_missing(self, protected, document, missing):
        result = self.check(protected, document)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertEqual(result.stdout.split(), missing)

    def test_host_route_listed_without_its_prefix(self):
        # nft prints a /32 element as a bare address: a text search for "/32" fails.
        self.assert_covered("192.168.1.0/24,203.0.113.7/32",
                            listing(prefix("192.168.1.0", 24), "203.0.113.7"))

    def test_auto_merge_folds_a_contained_network(self):
        self.assert_covered("10.0.0.0/8,10.1.0.0/16", listing(prefix("10.0.0.0", 8)))

    def test_adjacent_networks_merged_into_one_prefix_or_range(self):
        self.assert_covered("192.168.0.0/24,192.168.1.0/24", listing(prefix("192.168.0.0", 23)))
        self.assert_covered("192.168.0.0/24,192.168.1.0/24",
                            listing({"range": ["192.168.0.0", "192.168.1.255"]}))

    def test_union_of_adjacent_elements_covers_a_larger_network(self):
        self.assert_covered("10.0.0.0/8", listing(prefix("10.128.0.0", 9), prefix("10.0.0.0", 9)))

    def test_wrapped_elements_with_comments(self):
        self.assert_covered("172.16.0.0/12", listing({"elem": {"val": prefix("172.16.0.0", 12), "comment": "vpn"}}))

    def test_substring_of_another_network_is_not_coverage(self):
        # grep -F "10.1.0.0/16" used to match "110.1.0.0/16".
        self.assert_missing("10.1.0.0/16", listing(prefix("110.1.0.0", 16)), ["10.1.0.0/16"])

    def test_partial_coverage_reports_only_the_uncovered_network(self):
        self.assert_missing("10.0.0.0/8,192.168.1.0/24",
                            listing(prefix("10.0.0.0", 9), prefix("192.168.1.0", 24)), ["10.0.0.0/8"])

    def test_gap_between_elements_is_detected(self):
        self.assert_missing("10.0.0.0/8", listing(prefix("10.0.0.0", 10), prefix("10.128.0.0", 9)), ["10.0.0.0/8"])

    def test_empty_or_unreadable_set_is_never_coverage(self):
        self.assert_missing("192.168.1.0/24", listing(), ["192.168.1.0/24"])
        for document in ("", "not json", json.dumps({"nftables": [{"set": {"elem": [{"bogus": 1}]}}]})):
            self.assertEqual(self.check("192.168.1.0/24", document).returncode, 2, document)


class RuntimeCertificationUsesTheProof(unittest.TestCase):
    def test_certification_no_longer_greps_cidrs_in_the_table_text(self):
        core = (ROOT / "scripts/kvm/runtime_certification_core.sh").read_text()
        self.assertIn("nft-set-coverage.py", core)
        self.assertIn("nft -j list set inet", core)
        self.assertNotIn('grep -Fq "$cidr"', core)


if __name__ == "__main__":
    unittest.main()

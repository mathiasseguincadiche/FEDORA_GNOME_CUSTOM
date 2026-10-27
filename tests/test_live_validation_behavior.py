#!/usr/bin/env python3
"""Live observations stay portable preinstallation evidence, using only fixtures."""
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("live_validation", ROOT / "lib/live_validation.py")
LIVE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(LIVE)
CATALOG_TEXT = subprocess.check_output(
    ["bash", "-c", 'source "$1"; live_check_catalog', "bash",
     str(ROOT / "lib/live_preflight_probe.sh")], text=True)
CATALOG = LIVE.catalog_items(CATALOG_TEXT)
COMMIT = "1" * 40
PLAN = "2" * 64
HARDWARE = "3" * 64


def results(optional="NOT_TESTED"):
    return [{"id": identifier, "status": "PASS" if requirement == "required" else optional,
             "detail": "captured fixture observation"}
            for identifier, (requirement, _) in CATALOG.items()]


def report(checks):
    return ("SCHEMA\tfgc-live-preflight\t2\nSTATUS\tCHECK\tDETAIL\n" +
            "".join(f"{item['status']}\t{item['id']}\t{item['detail']}\n" for item in checks) +
            "SUMMARY\tFAIL=0\trequired NOT_TESTED=0\n"
            "DECISION\tGO\tpreinstallation only; installed system NOT_CERTIFIED\n")


def proof():
    return {"schema": 2, "gate": 2, "verdict": "PASS", "environment": "live-usb",
            "project_commit": COMMIT, "module_plan_sha256": PLAN,
            "source_tree_clean": True, "hardware_certification": "PREINSTALL_ONLY",
            "hardware_fingerprint_sha256": HARDWARE, "live_kernel": "7.1.8-live.fc45.x86_64",
            "checks": results(), "created_utc": "2026-10-27T12:00:00Z"}


def verify(value, commit=COMMIT, plan=PLAN, hardware=HARDWARE):
    LIVE.verify(value, CATALOG, commit, plan, hardware)


class LiveProofPolicy(unittest.TestCase):
    def test_real_catalog_has_all_sixteen_results(self):
        self.assertEqual(len(CATALOG), 16)
        self.assertEqual(sum(item[0] == "required" for item in CATALOG.values()), 6)
        parsed = LIVE.parse_report(report(results()), CATALOG)
        self.assertEqual(len(parsed), 16)
        self.assertEqual({item["id"] for item in parsed}, set(CATALOG))

    def test_every_observed_failure_is_refused_even_when_optional(self):
        for identifier in CATALOG:
            with self.subTest(check=identifier):
                value = proof()
                next(item for item in value["checks"] if item["id"] == identifier)["status"] = "FAIL"
                with self.assertRaises(ValueError):
                    verify(value)

    def test_every_required_not_tested_result_is_refused(self):
        for identifier, (requirement, _) in CATALOG.items():
            if requirement != "required":
                continue
            with self.subTest(check=identifier):
                value = proof()
                next(item for item in value["checks"] if item["id"] == identifier)["status"] = "NOT_TESTED"
                with self.assertRaises(ValueError):
                    verify(value)

    def test_optional_not_tested_is_only_preinstallation_evidence(self):
        value = proof()
        verify(value)
        self.assertEqual(value["hardware_certification"], "PREINSTALL_ONLY")
        self.assertTrue(any(item["status"] == "NOT_TESTED" for item in value["checks"]))
        for forbidden in ("PASS", "CERTIFIED", "Golden runtime-certified"):
            with self.subTest(hardware_certification=forbidden):
                forged = copy.deepcopy(value)
                forged["hardware_certification"] = forbidden
                with self.assertRaises(ValueError):
                    verify(forged)

    def test_report_requires_the_exact_version_two_schema_header(self):
        valid = report(results())
        for header in ("", "SCHEMA\tfgc-live-preflight\t1\n",
                       "SCHEMA\tother-report\t2\n"):
            with self.subTest(header=header):
                invalid = valid.replace("SCHEMA\tfgc-live-preflight\t2\n", header)
                with self.assertRaises(ValueError):
                    LIVE.parse_report(invalid, CATALOG)
        with self.assertRaises(ValueError):
            LIVE.parse_report(valid.replace("STATUS\tCHECK\tDETAIL\n", ""), CATALOG)

    def test_incomplete_duplicate_unknown_and_malformed_results_are_refused(self):
        baseline = results()
        mutations = [baseline[:-1], baseline + [copy.deepcopy(baseline[0])],
                     baseline + [{"id": "not_in_catalog", "status": "PASS", "detail": "fixture"}]]
        for checks in mutations:
            with self.subTest(checks=len(checks)):
                with self.assertRaises(ValueError):
                    LIVE.parse_report(report(checks), CATALOG)
        for field, replacement in (("status", "UNKNOWN"), ("detail", 1)):
            value = proof()
            value["checks"][0][field] = replacement
            with self.assertRaises(ValueError):
                verify(value)

    def test_legacy_schema_or_vm_environment_cannot_be_imported(self):
        for field, values in (("schema", (1, 0, "2", True)),
                              ("gate", (1, 3, "2")),
                              ("environment", ("wsl2", "virtualbox", "qemu", "vm", "baremetal")),
                              ("source_tree_clean", (False, "true"))):
            for replacement in values:
                with self.subTest(field=field, value=replacement):
                    value = proof()
                    value[field] = replacement
                    with self.assertRaises(ValueError):
                        verify(value)
        for change in ("missing", "additional"):
            value = proof()
            if change == "missing":
                del value["checks"]
            else:
                value["manual_visual"] = "PASS"
            with self.assertRaises(ValueError):
                verify(value)

    def test_source_module_plan_or_physical_identity_mismatch_is_refused(self):
        for expected in ({"commit": "a" * 40}, {"plan": "b" * 64}, {"hardware": "c" * 64}):
            with self.subTest(expected=expected):
                with self.assertRaises(ValueError):
                    verify(proof(), **expected)

    def test_observed_live_kernel_may_differ_from_installed_kernel(self):
        value = proof()
        installed_kernel = "7.3.2-vanilla.fc45.x86_64"
        self.assertNotEqual(value["live_kernel"], installed_kernel)
        with mock.patch.object(LIVE.subprocess, "check_output",
                               side_effect=AssertionError("verification must not probe the current kernel")):
            verify(value)
        for invalid in ("", None):
            value["live_kernel"] = invalid
            with self.assertRaises(ValueError):
                verify(value)

    def test_cli_creates_and_verifies_real_json_from_the_catalog_report(self):
        with tempfile.TemporaryDirectory(prefix="fgc-live-proof-") as directory:
            file = Path(directory) / "report.tsv"
            file.write_text(report(results()))
            common = ["--file", str(file), "--catalog", CATALOG_TEXT, "--commit", COMMIT,
                      "--module-plan", PLAN, "--hardware", HARDWARE]
            created = subprocess.run([sys.executable, str(ROOT / "lib/live_validation.py"),
                                      "create", *common, "--kernel", "fixture-live-kernel"],
                                     capture_output=True, text=True, timeout=10)
            self.assertEqual(created.returncode, 0, created.stderr)
            value = json.loads(created.stdout)
            self.assertEqual(value["hardware_certification"], "PREINSTALL_ONLY")
            self.assertEqual(len(value["checks"]), 16)
            self.assertEqual(value["live_kernel"], "fixture-live-kernel")
            file.write_text(created.stdout)
            verified = subprocess.run([sys.executable, str(ROOT / "lib/live_validation.py"),
                                       "verify", *common], capture_output=True, text=True, timeout=10)
            self.assertEqual(verified.returncode, 0, verified.stderr)
            schema = json.loads((ROOT / "manifests/validation-gate-proof.schema.json").read_text())
            self.assertEqual(set(value), set(schema["required"]))
            self.assertIs(schema["additionalProperties"], False)
            self.assertEqual(schema["properties"]["schema"]["const"], 2)
            self.assertEqual(schema["properties"]["hardware_certification"]["const"], "PREINSTALL_ONLY")


class StableHardwareIdentity(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="fgc-live-hardware-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.sysroot = self.root / "sys"
        board = self.sysroot / "class/dmi/id"
        board.mkdir(parents=True)
        (board / "board_vendor").write_text("Micro-Star International Co., Ltd.\n")
        (board / "board_name").write_text("MAG B850M MORTAR WIFI\n")
        self.card = self.sysroot / "class/drm/card7"
        self.add_gpu(self.card)
        self.add_gpu(self.sysroot / "class/drm/card7-DP-1")
        self.cpuinfo = self.root / "cpuinfo"
        self.cpuinfo.write_text(
            "processor : 0\nvendor_id : AuthenticAMD\ncpu family : 25\nmodel : 97\n"
            "stepping : 2\nmodel name : AMD Ryzen 7 7700 8-Core Processor\n"
            "cpu MHz : 2000\n\nprocessor : 1\ncpu MHz : 4000\n")
        self.disks = [dict(name="nvme0n1", type="disk", tran="nvme", model="CT1000T705SSD3", serial="SYSTEM-SERIAL"),
                      dict(name="nvme1n1", type="disk", tran="nvme", model="CT1000T705SSD3", serial="DATA-SERIAL")]

    @staticmethod
    def add_gpu(card):
        (card / "device").mkdir(parents=True)
        (card / "device/vendor").write_text("0x8086\n")
        (card / "device/device").write_text("0xe20b\n")

    def identity(self, disks=None):
        with mock.patch.object(LIVE.subprocess, "check_output",
                               side_effect=AssertionError("fixture identity must not inspect host disks")):
            return LIVE.hardware_identity(self.sysroot, self.cpuinfo,
                                          self.disks if disks is None else disks)

    def test_two_serials_are_sorted_and_gpu_connector_is_not_an_extra_gpu(self):
        identity = self.identity()
        self.assertEqual([disk["serial"] for disk in identity["nvme"]], ["DATA-SERIAL", "SYSTEM-SERIAL"])
        self.assertEqual(identity["gpu"], [("0x8086", "0xe20b")])

    def test_disk_names_root_uuid_card_indices_and_frequency_do_not_change_identity(self):
        before = self.identity()
        self.card.rename(self.card.with_name("card42"))
        disks = copy.deepcopy(list(reversed(self.disks)))
        for number, disk in enumerate(disks, 8):
            disk.update(name=f"nvme{number}n1", uuid="new-installed-root-uuid",
                        mountpoints=["/" if number == 8 else "/data"])
        self.cpuinfo.write_text(self.cpuinfo.read_text().replace("cpu MHz : 2000", "cpu MHz : 5500"))
        self.assertEqual(LIVE.digest_identity(before), LIVE.digest_identity(self.identity(disks)))
        self.assertEqual(set(before), {"cpu", "board", "gpu", "nvme"})
        self.assertTrue(all(set(disk) == {"model", "serial"} for disk in before["nvme"]))

    def test_missing_duplicate_or_extra_t705_serials_are_refused(self):
        duplicate = copy.deepcopy(self.disks)
        duplicate[1]["serial"] = duplicate[0]["serial"]
        empty = copy.deepcopy(self.disks)
        empty[0]["serial"] = ""
        for disks in ([], self.disks[:1], duplicate, empty,
                      self.disks + [dict(self.disks[0], serial="THIRD-SERIAL")]):
            with self.subTest(disks=disks):
                with self.assertRaises(ValueError):
                    self.identity(disks)

    def test_changed_physical_serial_or_board_changes_the_identity(self):
        original = LIVE.digest_identity(self.identity())
        disks = copy.deepcopy(self.disks)
        disks[0]["serial"] = "REPLACEMENT-SERIAL"
        self.assertNotEqual(original, LIVE.digest_identity(self.identity(disks)))
        (self.sysroot / "class/dmi/id/board_name").write_text("OTHER-BOARD")
        self.assertNotEqual(original, LIVE.digest_identity(self.identity()))

    def test_missing_cpu_or_real_b580_is_refused(self):
        shutil.rmtree(self.card)
        with self.assertRaises(ValueError):
            self.identity()
        self.add_gpu(self.card)
        self.cpuinfo.write_text("")
        with self.assertRaises(ValueError):
            self.identity()


if __name__ == "__main__":
    unittest.main(verbosity=2)

#!/usr/bin/env python3
"""Offline adversarial checks: libvirt metadata cannot expand backup scope."""
import importlib.util
from pathlib import Path
import sys
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("vm_backup_plan", ROOT / "scripts/backup/vm-backup-plan.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
UUID = "01234567-89ab-cdef-0123-456789abcdef"
DISK = '<disk type="file" device="disk"><driver type="qcow2"/><source file="/data/My VM.qcow2"/><target dev="vda"/></disk>'


def xml(*, disks=DISK, nvram="/var/lib/libvirt/qemu/nvram/demo_VARS.fd", tpm=""):
    return f'<domain><uuid>{UUID}</uuid><os><nvram>{nvram}</nvram></os><devices>{disks}{tpm}</devices></domain>'


class BackupPlanTests(unittest.TestCase):
    def test_good_domain_and_persistent_state(self):
        tpm = '<tpm><backend type="emulator"/></tpm>'
        result = module.plan(xml(tpm=tpm))
        self.assertEqual(result["disks"], [{"source": "/data/My VM.qcow2", "target": "vda"}])
        self.assertEqual(len(result["state_paths"]), 2)

    def test_path_traversal_controls_and_sentinels_rejected(self):
        bad = ["/", "//data/disk.qcow2", "/data/../etc/shadow", "/data//vm.qcow2",
               "/data/./vm.qcow2", "/etc/shadow", "/root/private.qcow2",
               "/proc/self/environ", "/dev/sda", "/run/secrets/key",
               "/data/a\nmultiline.qcow2", "relative.qcow2"]
        for path in bad:
            with self.subTest(path=path):
                modified = DISK.replace("/data/My VM.qcow2", path)
                with self.assertRaises(ValueError):
                    module.plan(xml(disks=modified))

    def test_bad_nvram_and_tpm_paths_rejected(self):
        for raw in ("/etc/shadow", "/data/../root/secret", "/proc/self/mem"):
            with self.subTest(field="NVRAM", path=raw):
                with self.assertRaises(ValueError):
                    module.plan(xml(nvram=raw))
            with self.subTest(field="TPM", path=raw):
                tpm = f'<tpm><backend type="emulator"><source path="{raw}"/></backend></tpm>'
                with self.assertRaises(ValueError):
                    module.plan(xml(tpm=tpm))

    def test_duplicate_sources_targets_and_state_rejected(self):
        repeated = DISK + DISK.replace("dev=\"vda\"", "dev=\"vdb\"")
        self.assertRaises(ValueError, module.plan, xml(disks=repeated))
        repeated = DISK + DISK.replace("My VM.qcow2", "other.qcow2")
        self.assertRaises(ValueError, module.plan, xml(disks=repeated))
        self.assertRaises(ValueError, module.plan, xml(nvram="/data/My VM.qcow2"))
        tpm = '<tpm><backend type="emulator"><source path="/var/lib/libvirt/qemu/nvram/demo_VARS.fd"/></backend></tpm>'
        self.assertRaises(ValueError, module.plan, xml(tpm=tpm))

    def test_unsupported_disks_are_not_skipped(self):
        self.assertRaises(ValueError, module.plan, xml(disks=DISK.replace('type="qcow2"', 'type="raw"')))
        self.assertRaises(ValueError, module.plan, xml(disks=DISK.replace('type="file"', 'type="block"')))


if __name__ == "__main__":
    unittest.main()

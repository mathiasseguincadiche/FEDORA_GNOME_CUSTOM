#!/usr/bin/env python3
"""Behavioral regressions for storage enrollment and exact offline completion."""
import copy
import contextlib
import io
import importlib.util
import json
import os
import shutil
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


storage = module('storage_identity', 'lib/persistent_data_identity.py')
offline = module('offline_history', 'scripts/maintenance/verify-offline-history.py')


class StorageIdentity(unittest.TestCase):
    def setUp(self):
        self.mounts, self.disks = {}, {}
        for index, target in enumerate(('/', '/data')):
            device = f'/dev/nvme{index}n1'
            self.mounts[target] = dict(source=device + 'p2', target=target,
                                       fstype='ext4' if index else 'btrfs',
                                       uuid=f'00000000-0000-4000-8000-00000000000{index}',
                                       options='rw,relatime')
            self.disks[device + 'p2'] = dict(name=device, type='disk',
                                           model='CT1000T705SSD3', serial=f'T705-{index}',
                                           wwn=f'eui.{index}')
        self.mock = patch.object(storage, 'read_json', side_effect=self.read)
        self.mock.start()
        self.addCleanup(self.mock.stop)

    def read(self, *args):
        if args[0] == 'findmnt':
            return {'filesystems': [copy.deepcopy(self.mounts[args[3]])]}
        return {'blockdevices': [dict(name=args[-1], type='part',
                                      children=[copy.deepcopy(self.disks[args[-1]])])]}

    def probe(self):
        return storage.probe('CT1000T705SSD3')

    def test_approved_distinct_physical_disks(self):
        expected = self.probe()
        storage.validate(expected, self.probe())
        # A kernel may renumber namespaces; stable serial/WWN/UUID remain valid.
        self.disks['/dev/nvme1n1p2']['name'] = '/dev/nvme7n1'
        storage.validate(expected, self.probe())

    def test_same_physical_disk_different_partition_refused(self):
        self.disks['/dev/nvme1n1p2'] = self.disks['/dev/nvme0n1p2']
        with self.assertRaises(ValueError):
            self.probe()

    def test_mount_and_disk_substitutions_refused(self):
        expected = self.probe()
        for field, value in [('serial', 'ANOTHER-T705'), ('wwn', 'other')]:
            with self.subTest(field=field):
                old = self.disks['/dev/nvme1n1p2'][field]
                self.disks['/dev/nvme1n1p2'][field] = value
                with self.assertRaises(ValueError):
                    storage.validate(expected, self.probe())
                self.disks['/dev/nvme1n1p2'][field] = old
        self.mounts['/data']['uuid'] = '11111111-1111-4111-8111-111111111111'
        with self.assertRaises(ValueError):
            storage.validate(expected, self.probe())

    def test_invalid_unmounted_readonly_usb_and_unknown_model(self):
        for field, value in [('target', '/'), ('fstype', 'btrfs'),
                             ('options', 'ro,relatime'), ('uuid', 'unknown')]:
            with self.subTest(field=field):
                old = self.mounts['/data'][field]
                self.mounts['/data'][field] = value
                with self.assertRaises(ValueError):
                    self.probe()
                self.mounts['/data'][field] = old
        for field, value in [('name', '/dev/sdb'), ('model', 'USB disk'), ('serial', '')]:
            old = self.disks['/dev/nvme1n1p2'][field]
            self.disks['/dev/nvme1n1p2'][field] = value
            with self.assertRaises(ValueError):
                self.probe()
            self.disks['/dev/nvme1n1p2'][field] = old

    def test_cli_requires_explicit_data_serial(self):
        with tempfile.TemporaryDirectory() as directory:
            identity = Path(directory) / 'approved.json'
            args = ['identity', 'enroll', '--model', 'CT1000T705SSD3',
                    '--identity', str(identity), '--confirm-serial']
            with patch('sys.argv', args + ['wrong']), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    storage.main()
            self.assertFalse(identity.exists())
            with patch('sys.argv', args + ['T705-1']), contextlib.redirect_stdout(io.StringIO()):
                storage.main()
            self.assertEqual(json.loads(identity.read_text()), self.probe())

    def test_enrollment_file_private_atomic_and_symlink_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'approved.json'
            payload = self.probe()
            storage.save(path, payload)
            self.assertEqual(json.loads(path.read_text()), payload)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            link = Path(directory) / 'link.json'
            link.symlink_to(path)
            with self.assertRaises(ValueError):
                storage.save(link, payload)


class OfflineCompletion(unittest.TestCase):
    token = 'fgc-offline-01234567-89ab-4cde-8fab-0123456789ab'

    def row(self):
        # Real DNF5 offline execute sets description, leaving comment empty.
        return dict(id=42, start_time=1001, end_time=1005, status='Ok', comment='',
                    description=f'dnf5 --refresh upgrade --offline -y --comment={self.token}')

    def test_success_among_other_transactions(self):
        self.assertEqual(offline.verify([self.row(), dict(description='dnf5 install jq')],
                                        self.token, 1000), 42)

    def test_old_failed_partial_missing_and_duplicate_refused(self):
        for change in [dict(status='Error'), dict(start_time=999), dict(id=0),
                       dict(end_time=1000), dict(end_time=None), dict(start_time=True),
                       dict(description='dnf5 upgrade --offline'),
                       dict(description=f'dnf5 upgrade --comment={self.token}'),
                       dict(description=f'dnf5 upgrade --offline --comment={self.token}-other')]:
            row = self.row() | change
            with self.subTest(change=change), self.assertRaises(ValueError):
                offline.verify([row], self.token, 1000)
        for rows in [[], [self.row(), self.row()], {}]:
            with self.assertRaises(ValueError):
                offline.verify(rows, self.token, 1000)


class SmartMeasurements(unittest.TestCase):
    def check(self, payload):
        script = '''SMART_FIXTURE="$2"
source "$1/lib/storage_health.sh"
storage_nvme_health_json() { cat "$SMART_FIXTURE"; }
storage_nvme_pcie_validate() { :; }
storage_nvme_validate_controller /dev/nvme0
'''
        with tempfile.NamedTemporaryFile(mode='w') as fixture:
            json.dump(payload, fixture)
            fixture.flush()
            return subprocess.run(['bash', '-c', script, '_', str(ROOT), fixture.name],
                                  capture_output=True).returncode

    def test_complete_measurements_and_invalid_payloads(self):
        measurements = dict(critical_warning=0, temperature=42, available_spare=100,
                            available_spare_threshold=10, percentage_used=0,
                            media_errors=0, num_err_log_entries=0)
        def wrap(value):
            return {'nvme_smart_health_information_log': value}
        self.assertEqual(self.check(wrap(measurements)), 0)
        self.assertNotEqual(self.check({}), 0)
        for key in measurements:
            missing = measurements.copy()
            del missing[key]
            self.assertNotEqual(self.check(wrap(missing)), 0, key)
        for key, value in [('temperature', 0), ('available_spare', 101),
                           ('media_errors', 1), ('critical_warning', 1),
                           ('percentage_used', '0'), ('critical_warning', False)]:
            self.assertNotEqual(self.check(wrap(measurements | {key: value})), 0)


class NetworkIntervals(unittest.TestCase):
    def test_real_nft_accepts_tailnet_with_nested_host_route(self):
        if not shutil.which('nft') or not shutil.which('unshare'):
            if os.environ.get('CI'):
                self.fail('nft and unshare are required by this regression in CI')
            self.skipTest('nft or network namespaces unavailable')
        code = (ROOT / 'scripts/kvm/kvm_network_guard.sh').read_text()
        code = code[:code.rindex('\ncase ')]+r"""
# Only route discovery is simulated; the real kernel validates and installs
# the real guard inside a fresh disposable network namespace.
discover_protected_ipv4() { printf '%s\n' 192.168.1.0/24 100.101.102.103/32; }
default_ipv4_device() { echo eth0; }
KVM_EXTRA_PROTECTED_CIDRS=100.64.0.0/10
reconcile_guard
nft list set inet "$TABLE_NAME" blocked_host_ipv4
"""
        with tempfile.NamedTemporaryFile(mode='w') as fixture:
            fixture.write(code)
            fixture.flush()
            command = ['unshare', '--net', 'bash', fixture.name]
            if os.geteuid() != 0:
                command = (['sudo', '-n'] + command if os.environ.get('CI') else
                           ['unshare', '--user', '--map-root-user', '--net', 'bash', fixture.name])
            result = subprocess.run(command, capture_output=True, text=True)
        if 'Operation not permitted' in result.stderr and not os.environ.get('CI'):
            self.skipTest('network namespaces unavailable')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('100.64.0.0/10', result.stdout)
        self.assertIn('192.168.1.0/24', result.stdout)


if __name__ == '__main__':
    unittest.main(verbosity=2)

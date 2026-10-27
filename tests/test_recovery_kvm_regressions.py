#!/usr/bin/env python3
"""Disposable regressions for LAN overlap and backup scope."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class RecoveryKvmRegressions(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="fgc-recovery-test-")
        self.addCleanup(self.temporary.cleanup)
        self.tmp = Path(self.temporary.name)
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ, PATH=str(self.bin) + ":/usr/bin:/bin", LC_ALL="C")

    def executable(self, name, source):
        target = self.bin / name
        target.write_text(source)
        target.chmod(0o755)

    def run_command(self, *arguments):
        return subprocess.run(arguments, env=self.env, text=True,
                              capture_output=True, timeout=20)

    def network_checks(self, routes):
        route_file = self.tmp / "routes"
        route_file.write_text(routes)
        self.env.update(ROUTE_FIXTURE=str(route_file), KVM_NETWORK_CIDR="192.168.50.0/24",
                        KVM_BRIDGE_NAME="virbr50", KVM_NFT_TABLE="fedora_gnome_custom_kvm",
                        KVM_BLOCK_ROUTED_HOST_NETWORKS="true", KVM_EXTRA_PROTECTED_CIDRS="")
        self.executable("ip", '''#!/usr/bin/env bash
case "$*" in
'-4 route show scope link'|'-4 route show table main') cat "$ROUTE_FIXTURE" ;;
'-4 route show default') echo 'default via 192.168.1.1 dev enp5s0' ;;
'-4 rule show') printf '%s\\n' '0: from all lookup local' '32766: from all lookup main' '32767: from all lookup default' ;;
*) exit 99 ;;
esac
''')
        self.executable("nft", '''#!/usr/bin/env bash
[[ "$*" == 'list table inet fedora_gnome_custom_kvm' ]] || exit 99
echo 'fedora-gnome-custom normal block VM to protected host networks'
''')
        preflight = self.run_command("bash", "-c",
            'source "$1/modules/virtualization/30_kvm_preflight.sh"; '
            'command_exists(){ command -v "$1" >/dev/null; }; '
            'kvm_preflight_network_overlap', "fixture", str(ROOT))
        guard = self.run_command("bash", str(ROOT / "scripts/kvm/kvm_network_guard.sh"), "check")
        return preflight, guard

    def test_physical_lan_equal_to_kvm_cidr_with_docker_is_rejected(self):
        preflight, guard = self.network_checks(
            "192.168.50.0/24 dev enp5s0 proto kernel scope link\n"
            "172.17.0.0/16 dev docker0 proto kernel scope link\n")
        self.assertNotEqual(preflight.returncode, 0)
        self.assertIn("overlaps host-connected route 192.168.50.0/24", preflight.stderr)
        self.assertNotEqual(guard.returncode, 0)
        self.assertIn("overlaps protected host network 192.168.50.0/24", guard.stderr)

    def test_existing_kvm_bridge_route_is_accepted(self):
        preflight, guard = self.network_checks(
            "192.168.1.0/24 dev enp5s0 proto kernel scope link\n"
            "192.168.50.0/24 dev virbr50 proto kernel scope link\n"
            "172.17.0.0/16 dev docker0 proto kernel scope link\n")
        self.assertEqual(preflight.returncode, 0, preflight.stderr)
        self.assertEqual(guard.returncode, 0, guard.stderr)
        self.assertIn("protected_networks=172.17.0.0/16,192.168.1.0/24\n", guard.stdout)

    def test_preapply_excludes_secrets_while_including_user_configuration(self):
        source = (ROOT / "prepare-preapply-backup.sh").read_text().splitlines()
        start = next(i for i, line in enumerate(source) if line == 'sources=("$staging")')
        end = next(i for i, line in enumerate(source[start:], start)
                   if "Borg archive creation failed" in line)
        home = self.tmp / "home"
        secrets = home / ".config/fedora-gnome-custom/secrets"
        secrets.mkdir(parents=True)
        (secrets / "token").write_text("synthetic token only\n")
        arguments_file = self.tmp / "engine-arguments"
        fragment = self.tmp / "preapply-fragment.sh"
        fragment.write_text('''set -Eeuo pipefail
backup_runtime_require_source_capacity(){ :; }
git(){ :; }
backup_engine_create(){ printf '%s\\n' "$@" > "$ARGUMENTS_FIXTURE"; printf 'fgc-preapply-fixture %064d\\n' 1; }
fail(){ echo "$*" >&2; exit 20; }
''' + "\n".join(source[start:end + 1]) + "\n")
        self.env.update(HOME=str(home), REPO_ROOT=str(ROOT),
                        staging=str(self.tmp / "staging"), repo="ssh://synthetic/./repo",
                        ARGUMENTS_FIXTURE=str(arguments_file))
        result = self.run_command("bash", str(fragment))
        self.assertEqual(result.returncode, 0, result.stderr)
        arguments = arguments_file.read_text().splitlines()
        exclusions = [arguments[i + 1] for i, value in enumerate(arguments)
                      if value == "--exclude"]
        self.assertIn(str(home / ".config"), arguments)
        self.assertIn(str(secrets), exclusions)


if __name__ == "__main__":
    unittest.main()

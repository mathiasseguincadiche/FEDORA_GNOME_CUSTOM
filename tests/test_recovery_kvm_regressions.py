#!/usr/bin/env python3
"""Disposable regressions for LAN overlap, recorded Windows health and backup scope."""
import json
import os
from pathlib import Path
import shutil
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

    def windows_doctor(self, marker=None, agent_available=True):
        fixture = self.tmp / "fixture"
        (fixture / "diagnostics").mkdir(parents=True)
        (fixture / "lib").mkdir()
        shutil.copyfile(ROOT / "diagnostics/windows-guest-doctor",
                        fixture / "diagnostics/windows-guest-doctor")
        (fixture / "lib/bootstrap.sh").write_text(
            'engine_bootstrap(){ :; }\n'
            'ui_check(){ printf "%s %s %s\\n" "$1" "$2" "$3"; }\n'
            'ui_meta(){ :; }\n')
        marker_file = self.tmp / "marker.json"
        if marker is not None:
            marker_file.write_text(json.dumps(marker))
        self.env.update(WINDOWS_MARKER_FIXTURE=str(marker_file),
                        QGA_AVAILABLE="1" if agent_available else "0")
        self.executable("virsh", '''#!/usr/bin/env python3
import base64,json,os,pathlib,sys
args=sys.argv[1:]
if "qemu-agent-command" not in args:
    sys.exit(0 if "list" in args or "dominfo" in args else 99)
cmd=json.loads(args[-1])["execute"]
marker=pathlib.Path(os.environ["WINDOWS_MARKER_FIXTURE"])
if cmd=="guest-ping":
    sys.exit(0 if os.environ["QGA_AVAILABLE"]=="1" else 1)
if cmd=="guest-file-open": result={"return":1} if marker.exists() else {"error":{}}
elif cmd=="guest-file-read": result={"return":{"buf-b64":base64.b64encode(marker.read_bytes()).decode(),"eof":True}}
elif cmd=="guest-file-close": result={"return":{}}
else: sys.exit(99)
print(json.dumps(result))
''')
        return self.run_command("bash", str(fixture / "diagnostics/windows-guest-doctor"))

    def recorded_pass(self):
        return dict(schema=2, verdict="PASS", generated_utc="2000-01-01T00:00:00Z",
                    virtio_bad_count=0, virtio_storage="PASS", virtio_network="PASS",
                    virtio_balloon="PASS", qemu_ga="PASS")

    def test_old_windows_marker_is_reported_as_recorded_not_live_health(self):
        result = self.windows_doctor(self.recorded_pass())
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("QEMU-GA guest-ping responds now", result.stdout)
        self.assertIn("last installation check PASS (2000-01-01T00:00:00Z)", result.stdout)
        self.assertIn("current VirtIO health not rechecked", result.stdout)
        self.assertNotIn("live VirtIO", result.stdout)

    def test_windows_marker_missing_is_rejected(self):
        result = self.windows_doctor()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("marker cannot be opened", result.stdout)

    def test_windows_failed_record_is_rejected(self):
        marker = self.recorded_pass()
        marker["virtio_storage"] = "FAIL"
        result = self.windows_doctor(marker)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("marker missing required PASS fields", result.stdout)

    def test_windows_agent_must_respond_now_even_with_recorded_pass(self):
        result = self.windows_doctor(self.recorded_pass(), agent_available=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("guest-ping failed", result.stdout)

    def test_windows_wrapper_reports_the_recorded_scope(self):
        self.windows_doctor(self.recorded_pass())
        fixture = self.tmp / "fixture"
        scripts = fixture / "scripts/kvm"
        scripts.mkdir(parents=True)
        shutil.copyfile(ROOT / "scripts/kvm/runtime_certification.sh",
                        scripts / "runtime_certification.sh")
        core = scripts / "runtime_certification_core.sh"
        core.write_text('#!/usr/bin/env bash\n'
                        'echo "OK host and Rocky fixture"\n'
                        'echo "WARN Windows guest integration obsolete advisory"\n')
        core.chmod(0o755)
        (fixture / "diagnostics/windows-guest-doctor").chmod(0o755)
        result = self.run_command("bash", str(scripts / "runtime_certification.sh"))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Windows QGA available + recorded installation check PASS", result.stdout)
        self.assertIn("current VirtIO health not rechecked", result.stdout)
        self.assertNotIn("obsolete advisory", result.stdout)
        self.assertNotIn("live guest contract", result.stdout)

    def windows_invalidation_prefix(self):
        source = (ROOT / "guest/windows-11/configure-guest-integration.ps1").read_text()
        prefix = source.split('Write-Host "[FGC] Detecting VirtIO media..."', 1)[0]
        self.assertIn("$markerPath = Join-Path $markerDir 'guest-integration.json'", prefix)
        self.assertIn("Remove-Item -LiteralPath $markerPath -Force", prefix)
        self.assertNotIn("SilentlyContinue", prefix)
        return prefix

    def test_windows_invalidates_record_before_fallible_media_detection(self):
        self.windows_invalidation_prefix()

    @unittest.skipUnless(shutil.which("pwsh"), "PowerShell runtime unavailable; invalidation ordering is checked separately")
    def test_windows_failed_attempt_removes_previous_marker(self):
        # Execute only the actual invalidation prefix, with its path relocated
        # into this fixture and the Administrator requirement removed for Linux.
        prefix = self.windows_invalidation_prefix()
        prefix = "\n".join(line for line in prefix.splitlines()
                           if not line.startswith("#Requires"))
        prefix = prefix.replace("$markerDir = 'C:\\ProgramData\\FedoraGnomeCustom'",
                                "$markerDir = $env:WINDOWS_MARKER_DIR")
        marker = self.tmp / "guest-integration.json"
        marker.write_text(json.dumps(self.recorded_pass()))
        script = self.tmp / "invalidation.ps1"
        script.write_text(prefix + '\nthrow "Synthetic media detection failure"\n')
        self.env["WINDOWS_MARKER_DIR"] = str(self.tmp)
        result = self.run_command(shutil.which("pwsh"), "-NoProfile", "-NonInteractive", "-File", str(script))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(marker.exists())

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

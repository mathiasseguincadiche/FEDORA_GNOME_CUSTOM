#!/usr/bin/env python3
"""Certify the Rocky-only public KVM path against disposable tool fixtures."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class RockyKvmRuntime(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="fgc-rocky-kvm-")
        self.addCleanup(self.temporary.cleanup)
        self.tmp = Path(self.temporary.name)
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ, PATH=str(self.bin) + ":/usr/bin:/bin", HOME=str(self.tmp / "home"),
                        VIRSH_FIXTURE_LOG=str(self.tmp / "virsh.log"))
        self.executable("virsh", '''#!/usr/bin/env python3
import os,pathlib,sys
args=sys.argv[1:]
if args[0] in ("--connect","-c"): args=args[2:]
with open(os.environ["VIRSH_FIXTURE_LOG"],"a") as log: log.write(" ".join(args)+"\\n")
cmd=args[0]
if cmd=="list": sys.exit(0)
if cmd=="domcapabilities": print(pathlib.Path(os.environ["DOMCAPS_FIXTURE"]).read_text())
elif cmd in ("dominfo","dumpxml","qemu-agent-command","domifaddr"):
    if args[1]!="rocky-devops": sys.exit(97)
    if cmd=="dominfo": print("Autostart: disable")
    elif cmd=="dumpxml": print(pathlib.Path(os.environ["DOMAIN_FIXTURE"]).read_text())
    elif cmd=="domifaddr": print("vnet0 52:54:00:00:00:01 ipv4 192.168.50.101/24")
    else: print('{"return":{}}')
else: sys.exit(98)
''')

    def executable(self, name, source):
        path = self.bin / name
        path.write_text(source)
        path.chmod(0o755)

    def run_script(self, path, *args):
        return subprocess.run(["bash", str(path), *args], env=self.env,
                              text=True, capture_output=True, timeout=20)

    def test_public_certification_with_only_rocky(self):
        fixture = self.tmp / "repo"
        for directory in ("config", "lib", "diagnostics", "scripts/kvm", "reports"):
            (fixture / directory).mkdir(parents=True)
        for name in ("runtime_certification.sh", "runtime_certification_core.sh"):
            shutil.copy2(ROOT / "scripts/kvm" / name, fixture / "scripts/kvm" / name)
        for name in ("virtualization.conf", "hardware-components.conf", "vm-profiles.conf"):
            shutil.copyfile(ROOT / "config" / name, fixture / "config" / name)
        with (fixture / "config/virtualization.conf").open("a") as handle:
            handle.write('\nKVM_BLOCK_PHYSICAL_LAN="false"\n')
        # Physical cgroup presence is fixture data; no host service is queried.
        controllers = self.tmp / "cgroup.controllers"
        controllers.write_text("cpu memory io\n")
        doctor = (ROOT / "diagnostics/kvm-domain-doctor").read_text()
        (fixture / "diagnostics/kvm-domain-doctor").write_text(
            doctor.replace("/sys/fs/cgroup/cgroup.controllers", str(controllers)))
        (fixture / "diagnostics/kvm-domain-doctor").chmod(0o755)
        (fixture / "diagnostics/kvm-io-doctor").write_text("#!/usr/bin/env bash\nexit 0\n")
        (fixture / "diagnostics/kvm-io-doctor").chmod(0o755)
        (fixture / "lib/bootstrap.sh").write_text(f'''
source "{ROOT}/lib/kvm_contract.sh"
engine_bootstrap() {{ REPORT_ROOT="{fixture}/reports"; RUN_ID=fixture; }}
runtime_is_baremetal() {{ return 0; }}
is_true() {{ [[ "$1" == true ]]; }}
ui_check() {{ printf '%s %s %s\\n' "$@"; }}
ui_meta() {{ :; }}
evidence_atomic_write() {{ cat > "$1"; }}
''')
        domcaps = self.tmp / "domcaps.xml"
        domcaps.write_text("""<domainCapabilities><domain>kvm</domain><arch>x86_64</arch>
<machine>pc-q35-10.0</machine><cpu><mode name='host-passthrough' supported='yes'/></cpu>
<os supported='yes'><enum name='firmware'><value>efi</value></enum></os></domainCapabilities>""")
        domain = self.tmp / "domain.xml"
        domain.write_text("""<domain type='kvm'><name>rocky-devops</name>
<memory unit='MiB'>16384</memory><vcpu>6</vcpu><cpu mode='host-passthrough'/>
<os firmware='efi'><type arch='x86_64' machine='pc-q35-10.0'>hvm</type></os><devices>
<disk device='disk'><driver type='qcow2' cache='none' io='io_uring' discard='unmap'/>
<source file='/data/libvirt/images/rocky-devops.qcow2'/><target bus='virtio'/></disk>
<interface type='network'><source network='devops-nat'/><model type='virtio'/></interface>
<channel><target name='org.qemu.guest_agent.0'/></channel>
<rng model='virtio'/><memballoon model='virtio'/></devices></domain>""")
        self.env.update(DOMCAPS_FIXTURE=str(domcaps), DOMAIN_FIXTURE=str(domain))
        self.executable("sudo", '#!/usr/bin/env bash\n[[ "$1" == virsh ]] || exit 99\nexec "$@"\n')
        self.executable("systemctl", '#!/usr/bin/env bash\n[[ "$1" != list-unit-files ]] || echo virtqemud.socket\nexit 0\n')
        self.executable("ssh", "#!/usr/bin/env bash\nexit 0\n")
        self.executable("ip", "#!/usr/bin/env bash\nexit 0\n")
        result = self.run_script(fixture / "scripts/kvm/runtime_certification.sh")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Rocky DevOps stack", result.stdout)
        self.assertIn("KO=0", result.stdout)
        calls = (self.tmp / "virsh.log").read_text()
        self.assertIn("dominfo rocky-devops", calls)
        self.assertIn("qemu-agent-command rocky-devops", calls)

    def test_bookmark_actions_use_only_rocky_sftp(self):
        # Execute the actual bookmark actions after their common-loader/root
        # preamble. Those independent guards are covered by preinstall tests.
        source = (ROOT / "scripts/kvm/configure_nautilus_vm_access.sh").read_text()
        script = self.tmp / "bookmarks.sh"
        script.write_text('set -Eeuo pipefail\nfail(){ echo "$*" >&2; exit 1; }\n'
                          'warn(){ echo "$*" >&2; }\n' + source[source.index('uri="'):])
        home = self.tmp / "home"
        bookmark = home / ".config/gtk-3.0/bookmarks"
        bookmark.parent.mkdir(parents=True)
        bookmark.write_text("smb://nas.example/data Personal NAS\n")
        self.env.update(HOME=str(home), XDG_CONFIG_HOME=str(home / ".config"))
        result = self.run_script(script, "refresh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(bookmark.read_text().splitlines(), [
            "smb://nas.example/data Personal NAS",
            "sftp://mathias@192.168.50.101/home/mathias Rocky DevOps"])
        calls = (self.tmp / "virsh.log").read_text()
        self.assertIn("domifaddr rocky-devops", calls)
        self.assertNotIn("domifaddr ", calls.replace("domifaddr rocky-devops", ""))


if __name__ == "__main__":
    unittest.main()

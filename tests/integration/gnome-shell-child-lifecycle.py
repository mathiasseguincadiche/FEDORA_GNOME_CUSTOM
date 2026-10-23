#!/usr/bin/env python3
"""Exercise real systemd stop ordering with an owned child dependency.

This models the dependency found in the GNOME trace, not Mutter itself. Both
fixture services exit normally and are collected; real GNOME failures are never
reset or ignored. The full GNOME QEMU test remains mandatory.
"""
import configparser
from pathlib import Path
import select
import signal
import subprocess
import sys
import tempfile
import time
import uuid


def fixture(directory):
    directory = Path(directory)
    child_code = """
import sys, time
print('ready', flush=True)
for line in sys.stdin:
    time.sleep(0.2)
    print('reply', flush=True)
"""
    child = subprocess.Popen([sys.executable, "-u", "-c", child_code],
                             stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                             text=True)
    stopping = False

    def stop(_signum, _frame):
        nonlocal stopping
        stopping = True

    signal.signal(signal.SIGTERM, stop)
    try:
        if child.stdout.readline().strip() != "ready":
            raise RuntimeError("fixture child did not start")
        (directory / "ready").touch()
        deadline = time.monotonic() + 20
        while not stopping:
            if time.monotonic() >= deadline:
                raise TimeoutError("fixture was never stopped")
            time.sleep(0.01)
        try:
            child.stdin.write("teardown roundtrip\n")
            child.stdin.flush()
            readable, _, _ = select.select([child.stdout], [], [], 2)
            reply = child.stdout.readline().strip() if readable else ""
        except BrokenPipeError:
            reply = ""
        (directory / "result").write_text("PASS" if reply == "reply" else "CHILD_GONE_EARLY")
    finally:
        child.stdin.close()
        try:
            child.wait(timeout=2)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait(timeout=2)


def exercise(mode, directory):
    unit = "fgc-child-lifecycle-test-" + uuid.uuid4().hex
    subprocess.run(["systemd-run", "--user", "--quiet", "--collect",
                    "--unit=" + unit, "--property=KillMode=" + mode,
                    "--property=TimeoutStopSec=5s", sys.executable,
                    str(Path(__file__).resolve()), "--fixture", str(directory)],
                   check=True, timeout=10)
    try:
        deadline = time.monotonic() + 10
        while not (directory / "ready").exists():
            if time.monotonic() >= deadline:
                raise TimeoutError("systemd fixture did not become ready")
            time.sleep(0.02)
        subprocess.run(["systemctl", "--user", "stop", unit], check=True, timeout=10)
        return (directory / "result").read_text()
    finally:
        # Only the two uniquely named fixture units belong to this test.
        subprocess.run(["systemctl", "--user", "stop", unit],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       timeout=10)


def main(policy_path):
    policy = configparser.ConfigParser()
    policy.read(policy_path)
    mode = policy["Service"]["KillMode"]
    if mode not in ("control-group", "mixed"):
        raise ValueError("unexpected service policy")
    with tempfile.TemporaryDirectory(prefix="fgc-child-lifecycle-") as temporary:
        root = Path(temporary)
        negative = root / "negative"
        positive = root / "positive"
        negative.mkdir()
        positive.mkdir()
        if exercise("control-group", negative) != "CHILD_GONE_EARLY":
            raise AssertionError("negative control did not reproduce premature child termination")
        if exercise(mode, positive) != "PASS":
            raise AssertionError("service stopped its child before the teardown roundtrip")
    print("Real systemd lifecycle: negative control reproduced; configured teardown PASS")


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--fixture":
        fixture(sys.argv[2])
    elif len(sys.argv) == 2:
        main(sys.argv[1])
    else:
        raise SystemExit("Usage: gnome-shell-child-lifecycle.py POLICY.conf")

#!/usr/bin/env python3
"""Observe a guest-originated QEMU reboot before retrying SSH."""
import json
import os
import socket
import subprocess
import sys
import time


def guest_reset(event):
    return (event.get("event") == "RESET"
            and event.get("data", {}).get("guest") is True
            and event.get("data", {}).get("reason") == "guest-reset")


def observe_reboot(path, command, seconds=180):
    deadline = time.monotonic() + seconds
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
        sock.settimeout(10)
        sock.connect(path)
        with sock.makefile("rb") as stream:
            def receive():
                sock.settimeout(max(0.01, deadline - time.monotonic()))
                raw = stream.readline()
                if not raw:
                    raise RuntimeError("QMP closed without a guest reboot")
                return json.loads(raw)

            if "QMP" not in receive():
                raise RuntimeError("invalid QMP greeting")
            sock.sendall(b'{"execute":"qmp_capabilities","id":"capabilities"}\r\n')
            while True:
                message = receive()
                if message.get("id") == "capabilities":
                    if "return" not in message:
                        raise RuntimeError("QMP capabilities refused")
                    break
            # A closed SSH reply is expected during reboot. RESET remains mandatory.
            try:
                result = subprocess.run(command, timeout=30, check=False)
                print(f"Reboot request SSH exit: {result.returncode}", flush=True)
            except subprocess.TimeoutExpired:
                print("SSH reply timed out; waiting for mandatory QMP RESET.", flush=True)
            while time.monotonic() < deadline:
                event = receive()
                print("QMP: " + json.dumps(event, sort_keys=True), flush=True)
                if guest_reset(event):
                    return
                if event.get("event") in ("SHUTDOWN", "GUEST_PANICKED"):
                    raise RuntimeError("guest stopped or panicked instead of rebooting")
            raise TimeoutError("no guest-originated QMP RESET")


if __name__ == "__main__":
    if os.environ.get("GITHUB_ACTIONS") != "true" or len(sys.argv) < 3:
        raise SystemExit("This helper requires the disposable GitHub laboratory.")
    observe_reboot(sys.argv[1], sys.argv[2:])

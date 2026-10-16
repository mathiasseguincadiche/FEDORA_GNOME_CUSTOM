#!/usr/bin/env python3
"""Regression: GNOME 51 extension CLI transport retries without false PASS."""
import importlib.util
from pathlib import Path
import subprocess
from types import SimpleNamespace

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "gnome51_lab_extension_list",
    root / ".github/scripts/fedora45-ci-extension-list.py",
)
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


def cli_result(code, stdout="", stderr=""):
    return SimpleNamespace(returncode=code, stdout=stdout, stderr=stderr)


def fake_cli(sequence, calls):
    pending = iter(sequence)

    def runner(command, **kwargs):
        assert command in (
            ["gnome-extensions", "list", "--active"],
            ["gnome-extensions", "list", "--enabled"],
        )
        assert kwargs == dict(capture_output=True, text=True, timeout=20, check=False)
        calls.append(command)
        item = next(pending)
        if isinstance(item, Exception):
            raise item
        return item
    return runner


# The first D-Bus query failed during CI's restored boot, but the six
# individual gnome-extensions info calls had succeeded. Accept only a later
# actual success response, never the failed command's stdout.
calls, sleeps = [], []
assert probe.list_extensions(
    "--active",
    attempts=3,
    interval=0,
    run=fake_cli(
        [cli_result(2, "incorrect-partial-output\n", "temporary D-Bus error"),
         cli_result(0, "a@example\nb@example\n")],
        calls,
    ),
    sleep=sleeps.append,
) == {"a@example", "b@example"}
assert len(calls) == 2 and sleeps == [0]

# Enabled and active are separate, mandatory successful queries.
calls = []
assert probe.list_extensions(
    "--enabled", attempts=1,
    run=fake_cli([cli_result(0, "a@example\n")], calls),
) == {"a@example"}
assert calls == [["gnome-extensions", "list", "--enabled"]]

# Success with no active extensions is not synthetic PASS: the caller's
# six-active assessment must fail. Do not substitute cached or expected UUIDs.
assert probe.list_extensions(
    "--active", attempts=1, run=fake_cli([cli_result(0, "")], [])
) == set()

# Repeated transport errors fail closed, including the last stderr and code.
calls = []
try:
    probe.list_extensions(
        "--active", attempts=3, interval=0,
        run=fake_cli([cli_result(2, stderr="no shell") for _ in range(3)], calls),
        sleep=lambda _: None,
    )
except RuntimeError as exc:
    assert "after 3 attempts" in str(exc) and "exit=2" in str(exc)
    assert "no shell" in str(exc)
else:
    raise AssertionError("Persistent GNOME CLI errors must fail")
assert len(calls) == 3

# No retries for unsupported options: this is a broken command contract.
calls = []
try:
    probe.list_extensions(
        "--enabled", run=fake_cli([cli_result(2, stderr="Unknown option --enabled")], calls),
        sleep=lambda _: (_ for _ in ()).throw(AssertionError("Must not retry CLI syntax")),
    )
except RuntimeError as exc:
    assert "Unknown option" in str(exc)
else:
    raise AssertionError("Unknown option cannot be silently retried")
assert len(calls) == 1

# A timed-out request can recover, but the budget is always finite.
calls = []
assert probe.list_extensions(
    "--active", attempts=2, interval=0,
    run=fake_cli([
        subprocess.TimeoutExpired(["gnome-extensions", "list", "--active"], timeout=20),
        cli_result(0, "a@example\n"),
    ], calls),
    sleep=lambda _: None,
) == {"a@example"}
assert len(calls) == 2

# Missing binary, unexpected option or unbounded budgets remain failures.
try:
    probe.list_extensions(
        "--active", attempts=1,
        run=fake_cli([FileNotFoundError("gnome-extensions not installed")], []),
    )
except FileNotFoundError:
    pass
else:
    raise AssertionError("Missing gnome-extensions binary accepted")
for flag, attempts in (("--disabled", 2), ("--active", 0), ("--active", 6)):
    try:
        probe.list_extensions(flag, attempts=attempts, run=lambda *a, **k: None)
    except ValueError:
        pass
    else:
        raise AssertionError("Invalid CLI query or retry budget accepted")

print("GNOME 51 candidate extension-list error/retry behavior: PASS")

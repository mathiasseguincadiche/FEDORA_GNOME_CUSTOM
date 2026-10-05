#!/usr/bin/env python3
"""Cancellation and accepted request handles cannot substitute for actual streams."""
import importlib.util
import pathlib
root = pathlib.Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("portal_probe", root / "scripts/validation/portal-stream-probe.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
assert probe.accepted_response((0, {"session_handle": "/session"}))["session_handle"] == "/session"
assert probe.stream_node({"streams": [(42, {})]}) == 42
for value in ((1, {}), (2, {})):
    try:
        probe.accepted_response(value)
    except RuntimeError:
        pass
    else:
        raise AssertionError("Cancellation/denial accepted")
for value in ({}, {"streams": []}, {"streams": [(0, {})]}, {"streams": [("42", {})]}):
    try:
        probe.stream_node(value)
    except RuntimeError:
        pass
    else:
        raise AssertionError("No usable stream accepted")
print("Portal response/stream negative cases: PASS")

#!/usr/bin/env python3
"""Consume portal-authorized frames without storing or uploading media."""
import argparse
import json
import os
import sys
import time
import uuid


def accepted_response(parameters):
    code, results = parameters
    if code != 0:
        raise RuntimeError("Portal request cancelled or denied (response=%s)" % code)
    return results


def stream_node(results):
    streams = results.get("streams", [])
    if not streams or not isinstance(streams[0][0], int) or streams[0][0] <= 0:
        raise RuntimeError("Start returned no usable PipeWire stream")
    return streams[0][0]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("kind", choices=("screen", "camera"))
    args = parser.parse_args()
    import gi
    gi.require_version("Gio", "2.0")
    gi.require_version("Gst", "1.0")
    from gi.repository import Gio, GLib, Gst
    Gst.init(None)
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    dest = "org.freedesktop.portal.Desktop"
    path = "/org/freedesktop/portal/desktop"
    session = None
    fd = None

    def request(iface, method, signature, values):
        replies = {}
        token = "fgc_" + uuid.uuid4().hex
        options = values[-1]
        options["handle_token"] = GLib.Variant("s", token)
        subscription = bus.signal_subscribe(
            dest, "org.freedesktop.portal.Request", "Response", None, None,
            Gio.DBusSignalFlags.NONE,
            lambda _b, _s, object_path, _i, _n, params: replies.update(
                {object_path: params.unpack()}))
        handle = None
        try:
            handle = bus.call_sync(dest, path, "org.freedesktop.portal." + iface,
                                   method, GLib.Variant(signature, values),
                                   GLib.VariantType.new("(o)"),
                                   Gio.DBusCallFlags.NONE, 15000, None).unpack()[0]
            deadline = time.monotonic() + 120
            context = GLib.MainContext.default()
            while handle not in replies and time.monotonic() < deadline:
                while context.pending():
                    context.iteration(False)
                time.sleep(0.02)
            if handle not in replies:
                raise RuntimeError("Portal response timed out")
            return accepted_response(replies[handle])
        finally:
            bus.signal_unsubscribe(subscription)
            if handle and handle not in replies:
                bus.call_sync(dest, handle, "org.freedesktop.portal.Request",
                              "Close", None, None, Gio.DBusCallFlags.NONE, 5000, None)

    def remote(iface, signature, values):
        answer, descriptors = bus.call_with_unix_fd_list_sync(
            dest, path, "org.freedesktop.portal." + iface, "OpenPipeWireRemote",
            GLib.Variant(signature, values), GLib.VariantType.new("(h)"),
            Gio.DBusCallFlags.NONE, 15000, None, None)
        return descriptors.get(answer.unpack()[0])

    pipeline = None
    try:
        node = None
        if args.kind == "screen":
            result = request("ScreenCast", "CreateSession", "(a{sv})", ({
                "session_handle_token": GLib.Variant("s", "fgc_" + uuid.uuid4().hex)},))
            session = result["session_handle"]
            request("ScreenCast", "SelectSources", "(oa{sv})", (session, {
                "types": GLib.Variant("u", 1),
                "multiple": GLib.Variant("b", False),
                "cursor_mode": GLib.Variant("u", 1)}))
            node = stream_node(request("ScreenCast", "Start", "(osa{sv})",
                                       (session, "", {})))
            fd = remote("ScreenCast", "(oa{sv})", (session, {}))
        else:
            request("Camera", "AccessCamera", "(a{sv})", ({},))
            fd = remote("Camera", "(a{sv})", ({},))
        pipeline = Gst.Pipeline.new("fgc-portal-frames")
        source = Gst.ElementFactory.make("pipewiresrc", "source")
        sink = Gst.ElementFactory.make("appsink", "sink")
        if source is None or sink is None:
            raise RuntimeError("PipeWire/appsink GStreamer plugins are missing")
        source.set_property("fd", fd)
        source.set_property("do-timestamp", True)
        if node is not None:
            source.set_property("path", str(node))
        sink.set_property("sync", False)
        sink.set_property("max-buffers", 2)
        sink.set_property("drop", True)
        pipeline.add(source)
        pipeline.add(sink)
        if not source.link(sink):
            raise RuntimeError("Cannot link portal stream")
        if pipeline.set_state(Gst.State.PLAYING) == Gst.StateChangeReturn.FAILURE:
            raise RuntimeError("Cannot start portal stream")
        frames = 0
        deadline = time.monotonic() + 30
        media_type = None
        while frames < 10 and time.monotonic() < deadline:
            error = pipeline.get_bus().pop_filtered(Gst.MessageType.ERROR)
            if error:
                raise RuntimeError(str(error.parse_error()[0]))
            sample = sink.emit("try-pull-sample", Gst.SECOND)
            if sample is None:
                continue
            caps = sample.get_caps()
            buffer = sample.get_buffer()
            media_type = caps.get_structure(0).get_name() if caps else None
            if media_type not in ("video/x-raw", "image/jpeg") or not buffer or buffer.get_size() <= 0:
                raise RuntimeError("Portal returned no usable video frame")
            frames += 1
        if frames < 10:
            raise RuntimeError("Insufficient frames: %s/10" % frames)
        print(json.dumps({"status": "PASS", "policy": 2, "kind": args.kind,
                          "frames": frames, "media_type": media_type,
                          "media_saved": False}))
    finally:
        if pipeline is not None:
            pipeline.set_state(Gst.State.NULL)
        if fd is not None:
            os.close(fd)
        if session is not None:
            bus.call_sync(dest, session, "org.freedesktop.portal.Session", "Close",
                          None, None, Gio.DBusCallFlags.NONE, 5000, None)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("BLOCKED: " + str(exc), file=sys.stderr)
        sys.exit(1)

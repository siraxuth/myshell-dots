#!/usr/bin/env python3
"""Display an immutable desktop snapshot while slurp selects a region."""

import argparse
import json
import signal
import subprocess
from pathlib import Path

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkPixbuf", "2.0")
gi.require_version("GLibUnix", "2.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import (  # noqa: E402
    Gdk,
    GdkPixbuf,
    GLib,
    GLibUnix,
    Gtk,
    GtkLayerShell,
)


def args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", required=True)
    parser.add_argument("--origin-x", required=True, type=int)
    parser.add_argument("--origin-y", required=True, type=int)
    parser.add_argument("--ready-file", required=True)
    return parser.parse_args()


def monitors():
    return json.loads(
        subprocess.check_output(["hyprctl", "-j", "monitors"], text=True)
    )


def gdk_monitor_for(rect):
    display = Gdk.Display.get_default()
    fallback = None
    for index in range(display.get_n_monitors()):
        monitor = display.get_monitor(index)
        fallback = fallback or monitor
        geometry = monitor.get_geometry()
        if (geometry.x, geometry.y, geometry.width, geometry.height) == rect:
            return monitor
    return fallback


def main():
    options = args()
    desktop = GdkPixbuf.Pixbuf.new_from_file(options.image)
    windows = []

    for monitor in monitors():
        x = int(monitor["x"])
        y = int(monitor["y"])
        width = int(monitor["width"])
        height = int(monitor["height"])
        crop_x = x - options.origin_x
        crop_y = y - options.origin_y
        image = desktop.new_subpixbuf(crop_x, crop_y, width, height)

        window = Gtk.Window(title="Frozen screenshot")
        window.set_decorated(False)
        window.set_accept_focus(False)
        window.set_can_focus(False)
        window.set_app_paintable(True)

        GtkLayerShell.init_for_window(window)
        GtkLayerShell.set_namespace(window, "screenshot-freeze")
        GtkLayerShell.set_layer(window, GtkLayerShell.Layer.OVERLAY)
        GtkLayerShell.set_keyboard_mode(window, GtkLayerShell.KeyboardMode.NONE)
        # -1 makes the surface ignore panels/docks' reserved areas. With 0,
        # Hyprland shrinks it to the usable workspace (e.g. 1850x1060 at
        # x=60,y=10), which scales the 1920x1080 snapshot and breaks slurp's
        # coordinate mapping.
        GtkLayerShell.set_exclusive_zone(window, -1)
        for edge in (
            GtkLayerShell.Edge.LEFT,
            GtkLayerShell.Edge.RIGHT,
            GtkLayerShell.Edge.TOP,
            GtkLayerShell.Edge.BOTTOM,
        ):
            GtkLayerShell.set_anchor(window, edge, True)

        gdk_monitor = gdk_monitor_for((x, y, width, height))
        if gdk_monitor is not None:
            GtkLayerShell.set_monitor(window, gdk_monitor)

        window.add(Gtk.Image.new_from_pixbuf(image))
        window.realize()
        if window.get_window() is not None:
            window.get_window().set_pass_through(True)
        window.show_all()
        windows.append(window)

    def quit_overlay(*_unused):
        Gtk.main_quit()
        return GLib.SOURCE_REMOVE

    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, quit_overlay)
    GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, quit_overlay)

    def signal_ready():
        Gdk.Display.get_default().flush()
        Path(options.ready_file).touch()
        return GLib.SOURCE_REMOVE

    GLib.timeout_add(80, signal_ready)
    Gtk.main()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Snip-&-Sketch-style launcher: pick Screenshot/Record x Full-screen/Window/Region,
then hands off to the existing capture pipeline (screenshot-smart.sh / caelestia record).

Native GTK+WebKit, real per-pixel transparency for a floating rounded card (not a
plain rectangle) -- no qs/dunst involved.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("WebKit2", "4.1")
from gi.repository import Gtk, WebKit2, GLib, Gdk  # noqa: E402

GLib.set_prgname("capture-dashboard")

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS_DIR = os.path.expanduser("~/.config/hypr/scripts")
CACHE_DIR = os.path.expanduser("~/.cache/caelestia/screenshots")
OWN_CLASSES = {"capture-dashboard", "screenshot-editor"}


def hyprctl_json(*args):
    return json.loads(subprocess.check_output(["hyprctl", "-j", *args], text=True))


def get_monitors():
    mons = hyprctl_json("monitors")
    return [{"name": m["name"], "width": m["width"], "height": m["height"],
              "x": m["x"], "y": m["y"], "focused": m.get("focused", False)}
             for m in mons]


def get_windows():
    clients = hyprctl_json("clients")
    out = []
    for c in clients:
        if not c.get("mapped"):
            continue
        if c.get("class") in OWN_CLASSES:
            continue
        ws = c.get("workspace", {}).get("name", "")
        if ws.startswith("special"):
            continue
        out.append({
            "address": c["address"],
            "title": c.get("title") or c.get("class", "?"),
            "class": c.get("class", "?"),
            "at": c.get("at", [0, 0]),
            "size": c.get("size", [0, 0]),
        })
    return out


def get_focused_window_address():
    try:
        active = hyprctl_json("activewindow")
        return active.get("address")
    except Exception:
        return None


def get_cursor_position():
    try:
        out = subprocess.check_output(["hyprctl", "cursorpos"], text=True).strip()
        return tuple(int(v.strip()) for v in out.split(","))
    except Exception:
        return None


def grim_geometry(x, y, w, h):
    return f"{x},{y} {w}x{h}"


def record_geometry(x, y, w, h):
    return f"{w}x{h}+{x}+{y}"


class Dashboard:
    def __init__(self):
        self.monitors = get_monitors()
        self.windows = get_windows()
        self.snapshot_dir = None
        self.snapshot_cursor = None
        self.snapshot_clean = None
        self.snapshot_rect = self._virtual_rect()

        # Capture the desktop before the dashboard is mapped. This preserves
        # the exact page, :hover state and original pointer position from the
        # instant Win+Shift+S was pressed.
        self._capture_initial_snapshots()

        focused_mon = next((m["name"] for m in self.monitors if m["focused"]), None)
        focused_win = get_focused_window_address()

        with open(os.path.join(HERE, "dashboard.html"), encoding="utf-8") as f:
            html = f.read()
        html = (html
                .replace("__MONITORS_JSON__", json.dumps(self.monitors))
                .replace("__WINDOWS_JSON__", json.dumps(self.windows))
                .replace("__FOCUSED_MONITOR_JSON__", json.dumps(focused_mon))
                .replace("__FOCUSED_WINDOW_JSON__", json.dumps(focused_win)))

        self.win = Gtk.Window(title="จับภาพหน้าจอ")
        self.win.set_decorated(False)
        self.win.set_resizable(False)
        self.win.set_default_size(*self._sized())
        self.win.set_app_paintable(True)
        self._enable_transparency()
        self.win.connect("destroy", lambda *_: Gtk.main_quit())

        ucm = WebKit2.UserContentManager()
        ucm.register_script_message_handler("bridge")
        ucm.connect("script-message-received::bridge", self.on_message)

        self.webview = WebKit2.WebView.new_with_user_content_manager(ucm)
        self.webview.set_background_color(Gdk.RGBA(0, 0, 0, 0))
        self.webview.load_html(html, "file://" + HERE + "/")

        self.win.add(self.webview)
        self.win.show_all()

    def _virtual_rect(self):
        if not self.monitors:
            return None
        x1 = min(m["x"] for m in self.monitors)
        y1 = min(m["y"] for m in self.monitors)
        x2 = max(m["x"] + m["width"] for m in self.monitors)
        y2 = max(m["y"] + m["height"] for m in self.monitors)
        return (x1, y1, x2 - x1, y2 - y1)

    def _capture_initial_snapshots(self):
        if self.snapshot_rect is None:
            return

        runtime_dir = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
        self.snapshot_dir = tempfile.mkdtemp(
            prefix="capture-dashboard-", dir=runtime_dir
        )
        self.snapshot_cursor = os.path.join(self.snapshot_dir, "desktop-cursor.png")
        self.snapshot_clean = os.path.join(self.snapshot_dir, "desktop-clean.png")

        x, y, w, h = self.snapshot_rect
        geometry = grim_geometry(x, y, w, h)
        old_invisible = False
        try:
            option = hyprctl_json("getoption", "cursor:invisible")
            old_invisible = bool(option.get("int", 0))
        except Exception:
            pass

        try:
            # Cursor version first: this is the exact visual state the user
            # asked to preserve, including the pointer at its original spot.
            subprocess.run(
                ["grim", "-s", "1", "-c", "-g", geometry,
                 self.snapshot_cursor],
                check=True,
            )

            # Hiding the compositor cursor does not move pointer focus, so web
            # hover remains active while producing the clean variant.
            subprocess.run(
                ["hyprctl", "keyword", "cursor:invisible", "true"],
                check=True,
                stdout=subprocess.DEVNULL,
            )
            time.sleep(0.05)
            subprocess.run(
                ["grim", "-s", "1", "-g", geometry,
                 self.snapshot_clean],
                check=True,
            )
        except (OSError, subprocess.CalledProcessError):
            self.cleanup_snapshots()
        finally:
            subprocess.run(
                ["hyprctl", "keyword", "cursor:invisible",
                 "true" if old_invisible else "false"],
                check=False,
                stdout=subprocess.DEVNULL,
            )

    def cleanup_snapshots(self):
        if self.snapshot_dir:
            shutil.rmtree(self.snapshot_dir, ignore_errors=True)
        self.snapshot_dir = None
        self.snapshot_cursor = None
        self.snapshot_clean = None

    def _snapshot_source(self, cursor):
        source = self.snapshot_cursor if cursor else self.snapshot_clean
        return source if source and os.path.isfile(source) else None

    def _enable_transparency(self):
        screen = self.win.get_screen()
        visual = screen.get_rgba_visual()
        if visual and screen.is_composited():
            self.win.set_visual(visual)

    def _sized(self):
        try:
            mons = hyprctl_json("monitors")
            mon = next((m for m in mons if m.get("focused")), mons[0])
            scale = mon.get("scale", 1) or 1
            h = mon["height"] / scale
            # Compact card: fixed comfortable width, height scales a little
            # with the monitor so it never feels cramped on small displays.
            return 440, min(620, max(560, int(h * 0.62)))
        except Exception:
            return 440, 600

    def on_message(self, _ucm, result):
        try:
            payload = json.loads(result.get_js_value().to_string())
        except Exception:
            return
        action = payload.get("action")
        if action == "close":
            Gtk.main_quit()
        elif action == "go":
            self._dismiss_then(lambda: self._dispatch(payload))

    def _dismiss_then(self, fn):
        # Hide + flush the GTK event loop BEFORE launching any capture so this
        # card is never itself in the screenshot/recording.
        self.win.hide()
        while Gtk.events_pending():
            Gtk.main_iteration()
        time.sleep(0.06)
        try:
            fn()
        finally:
            Gtk.main_quit()

    def _dispatch(self, p):
        mode = p.get("mode")
        target = p.get("target")
        sound = bool(p.get("sound"))
        cursor = bool(p.get("cursor"))

        if target == "region":
            if mode == "shot":
                source = self._snapshot_source(cursor)
                if source and self.snapshot_rect:
                    x, y, _w, _h = self.snapshot_rect
                    args = [
                        "bash", f"{SCRIPTS_DIR}/screenshot-smart.sh",
                        "--snapshot", source,
                        "--origin-x", str(x),
                        "--origin-y", str(y),
                    ]
                    # Keep this process alive so the temporary snapshot remains
                    # available until selection and cropping are complete.
                    subprocess.run(args, check=False)
                else:
                    args = ["bash", f"{SCRIPTS_DIR}/screenshot-smart.sh", "--freeze"]
                    if cursor:
                        args.append("--cursor")
                    subprocess.Popen(args, start_new_session=True)
            else:
                args = ["caelestia", "record", "-r"]
                if sound:
                    args.append("-s")
                subprocess.Popen(args, start_new_session=True)
            return

        if target == "full":
            mon = next((m for m in self.monitors if m["name"] == p.get("monitor")), None)
            if mon is None:
                return
            if mode == "shot":
                source = self._snapshot_source(cursor)
                if source:
                    self._snapshot_and_edit(
                        (mon["x"], mon["y"], mon["width"], mon["height"]),
                        source,
                    )
                else:
                    self._grim_and_edit("-o", mon["name"], cursor)
            else:
                args = ["caelestia", "record"]
                if not mon["focused"]:
                    args += ["-r", record_geometry(mon["x"], mon["y"], mon["width"], mon["height"])]
                if sound:
                    args.append("-s")
                subprocess.Popen(args, start_new_session=True)
            return

        if target == "window":
            addr = p.get("windowAddress")
            if mode == "shot":
                try:
                    win = next(c for c in self.windows if c["address"] == addr)
                except StopIteration:
                    return
                x, y = win["at"]
                w, h = win["size"]
                source = self._snapshot_source(cursor)
                if source:
                    self._snapshot_and_edit((x, y, w, h), source)
                else:
                    self._grim_and_edit("-g", grim_geometry(x, y, w, h), cursor)
            else:
                try:
                    clients = hyprctl_json("clients")
                    win = next(c for c in clients if c["address"] == addr)
                except (StopIteration, subprocess.CalledProcessError):
                    return
                x, y = win["at"]
                w, h = win["size"]
                args = ["caelestia", "record", "-r", record_geometry(x, y, w, h)]
                if sound:
                    args.append("-s")
                subprocess.Popen(args, start_new_session=True)
            return

    def _capture_rect(self, flag, value):
        """Absolute (x, y, w, h) of what's about to be captured, or None."""
        if flag == "-o":
            mon = next((m for m in self.monitors if m["name"] == value), None)
            return (mon["x"], mon["y"], mon["width"], mon["height"]) if mon else None
        if flag == "-g":
            try:
                pos, size = value.split(" ")
                x, y = (int(v) for v in pos.split(","))
                w, h = (int(v) for v in size.split("x"))
                return (x, y, w, h)
            except Exception:
                return None
        return None

    def _park_cursor_away_from(self, rect):
        """Move the live cursor outside `rect` and return its old position."""
        original = get_cursor_position()
        if original is None:
            return None
        rx, ry, rw, rh = rect

        # A corner on the same monitor is usually sufficient for a window or
        # region capture; using only a completely separate monitor made the old
        # implementation unnecessarily fail on common layouts.
        for m in self.monitors:
            mx, my, mw, mh = m["x"], m["y"], m["width"], m["height"]
            candidates = [
                (mx + 8, my + 8),
                (mx + mw - 8, my + 8),
                (mx + 8, my + mh - 8),
                (mx + mw - 8, my + mh - 8),
                (mx + mw // 2, my + mh // 2),
            ]
            for x, y in candidates:
                if rx <= x < rx + rw and ry <= y < ry + rh:
                    continue
                subprocess.run(["hyprctl", "dispatch", "movecursor",
                                 str(x), str(y)], check=False)
                return original
        return None  # capture spans every monitor -- nowhere safe to park

    def _start_freeze(self, include_cursor=False):
        """Freeze the restored hover frame; return the hyprpicker process."""
        # Prefer the user-local current build. /usr/bin/hyprpicker on this
        # machine is an unowned stale binary linked to libhyprutils.so.11.
        picker = os.path.expanduser("~/.local/bin/hyprpicker")
        if not os.access(picker, os.X_OK):
            picker = shutil.which("hyprpicker")
        if not picker:
            return None
        args = [picker, "-r", "-z", "-q"]
        if include_cursor:
            args.append("-c")
        proc = subprocess.Popen(
            args,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        time.sleep(0.22)
        if proc.poll() is not None:
            return None
        return proc

    def _open_shot(self, shot):
        with open(shot, "rb") as image:
            subprocess.run(["wl-copy"], input=image.read(), check=False)
        subprocess.Popen(
            ["/usr/bin/python3", f"{SCRIPTS_DIR}/screenshot-editor/editor.py", shot],
            start_new_session=True,
        )

    def _snapshot_and_edit(self, rect, source):
        """Crop a target from the immutable desktop captured at hotkey time."""
        if self.snapshot_rect is None:
            return
        x, y, w, h = rect
        origin_x, origin_y, _vw, _vh = self.snapshot_rect
        crop_x = x - origin_x
        crop_y = y - origin_y

        os.makedirs(CACHE_DIR, exist_ok=True)
        shot = os.path.join(
            CACHE_DIR, datetime.now().strftime("%Y%m%d-%H%M%S") + ".png"
        )
        subprocess.run(
            ["magick", source, "-crop",
             f"{w}x{h}+{crop_x}+{crop_y}", "+repage", shot],
            check=True,
        )
        self._open_shot(shot)

    def _grim_and_edit(self, flag, value, cursor=False):
        os.makedirs(CACHE_DIR, exist_ok=True)
        shot = os.path.join(CACHE_DIR, datetime.now().strftime("%Y%m%d-%H%M%S") + ".png")
        # Keep the browser's restored hover frame visible while grim captures
        # it. If freezing fails, retain the old live-capture fallback.
        freezer = self._start_freeze(include_cursor=cursor)
        cmd = ["grim"]
        if cursor and freezer is None:
            cmd.append("-c")
        cmd += [flag, value, shot]

        # grim's -c/no-c only toggles a hw-plane cursor overlay; with
        # no_hardware_cursors=true (needed by dynamic-cursors shake-to-find) the
        # cursor is baked into every frame regardless of the flag, so "hide" has
        # to physically park the cursor off the captured rect instead.
        restore_pos = None
        if freezer is not None or not cursor:
            rect = self._capture_rect(flag, value)
            if rect:
                restore_pos = self._park_cursor_away_from(rect)
                if restore_pos:
                    time.sleep(0.08)

        try:
            subprocess.run(cmd, check=True)
        finally:
            if freezer is not None:
                freezer.terminate()
                try:
                    freezer.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    freezer.kill()
            if restore_pos:
                subprocess.run(["hyprctl", "dispatch", "movecursor",
                                 str(restore_pos[0]), str(restore_pos[1])], check=False)
        self._open_shot(shot)


def main():
    dashboard = Dashboard()
    try:
        Gtk.main()
    finally:
        dashboard.cleanup_snapshots()


if __name__ == "__main__":
    main()

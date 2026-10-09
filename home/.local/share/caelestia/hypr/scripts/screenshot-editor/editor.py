#!/usr/bin/env python3
"""All-in-one screenshot editor: big preview, draw/annotate tools, and an
OCR text layer (like Windows Snipping Tool's Text Actions) so recognized
text can be click-dragged and copied directly off the image.

Native GTK+WebKit window -- does NOT touch qs or dunst, so it isn't affected
by the quickshell notification-daemon hang/leak on this box.
"""
import base64
import json
import os
import subprocess
import sys
import tempfile
import threading
from datetime import datetime

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("WebKit2", "4.1")
from gi.repository import Gtk, WebKit2, GLib, Gio, Gdk  # noqa: E402

# Sets WM_CLASS / Wayland app_id so the Hyprland windowrule (float + center)
# in hyprland/rules.conf can target this window precisely.
GLib.set_prgname("screenshot-editor")

HERE = os.path.dirname(os.path.abspath(__file__))
LANG = "eng+tha"
SCREENSHOTS_DIR = os.path.expanduser("~/Pictures/Screenshots")


def notify(title, body=""):
    try:
        subprocess.run(["notify-send", "-a", "caelestia-cli", "-t", "3000",
                         "-i", "edit-copy", title, body],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def run_ocr(image_path, scale, multi_psm):
    """Returns (words, full_text). words: list of dicts in ORIGINAL image px."""
    tmpdir = tempfile.mkdtemp(prefix="ocr-")
    try:
        ocr_input = image_path
        if scale != 1:
            ocr_input = os.path.join(tmpdir, "scaled.png")
            args = ["magick", image_path, "-colorspace", "Gray",
                     "-resize", f"{int(scale*100)}%"]
            if multi_psm:
                args += ["-despeckle", "-normalize", "-unsharp", "0x1", "-sharpen", "0x1"]
            args.append(ocr_input)
            subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        psms = [3, 6, 11] if multi_psm else [3]
        best_words, best_text = [], ""
        for psm in psms:
            tsv_path = os.path.join(tmpdir, f"out_{psm}")
            subprocess.run(
                ["tesseract", ocr_input, tsv_path, "-l", LANG, "--oem", "1",
                 "--psm", str(psm), "tsv"],
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            words, texts = [], []
            with open(tsv_path + ".tsv", encoding="utf-8") as f:
                next(f, None)
                for line in f:
                    cols = line.rstrip("\n").split("\t")
                    if len(cols) < 12:
                        continue
                    level, left, top, width, height, conf, text = (
                        cols[0], cols[6], cols[7], cols[8], cols[9], cols[10], cols[11]
                    )
                    if level != "5" or not text.strip():
                        continue
                    try:
                        conf_f = float(conf)
                    except ValueError:
                        conf_f = -1
                    if conf_f < 30:
                        continue
                    words.append({
                        "left": float(left) / scale,
                        "top": float(top) / scale,
                        "width": float(width) / scale,
                        "height": float(height) / scale,
                        "text": text,
                    })
                    texts.append(text)
            full = " ".join(texts)
            if len(full) > len(best_text):
                best_words, best_text = words, full
        return best_words, best_text
    finally:
        subprocess.run(["rm", "-rf", tmpdir])


class Editor:
    def __init__(self, image_path):
        self.image_path = image_path

        with open(os.path.join(HERE, "editor.html"), encoding="utf-8") as f:
            html = f.read()
        # data: URI, not file:// -- an <img src="file://..."> loaded from a
        # different directory than the page's own base taints the canvas
        # (WebKit treats it as cross-origin), so flatten()'s toDataURL()
        # throws SecurityError silently (devtools are off) and Save/Copy
        # never even reach the bridge. Inline data: URIs don't taint.
        with open(image_path, "rb") as imgf:
            img_b64 = base64.b64encode(imgf.read()).decode()
        html = html.replace("IMG_SRC_PLACEHOLDER", f"data:image/png;base64,{img_b64}")

        self.win = Gtk.Window(title="จับภาพหน้าจอ")
        self.win.set_default_size(*self._sized_for_focused_monitor())
        self.win.connect("destroy", lambda *_: Gtk.main_quit())

        ucm = WebKit2.UserContentManager()
        ucm.register_script_message_handler("bridge")
        ucm.connect("script-message-received::bridge", self.on_message)

        self.webview = WebKit2.WebView.new_with_user_content_manager(ucm)
        settings = self.webview.get_settings()
        settings.set_enable_developer_extras(False)
        self.webview.load_html(html, "file://" + HERE + "/")

        self.win.add(self.webview)
        self.win.show_all()

    def _sized_for_focused_monitor(self):
        # Prefer Hyprland's own idea of the focused monitor (dual-monitor
        # setup: HDMI on top, eDP on bottom) over GTK/Gdk's default one.
        try:
            mons = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True))
            mon = next((m for m in mons if m.get("focused")), mons[0])
            w, h = mon["width"] / mon.get("scale", 1), mon["height"] / mon.get("scale", 1)
            return int(w * 0.82), int(h * 0.84)
        except Exception:
            return 1280, 860

    def js(self, script):
        GLib.idle_add(lambda: self.webview.run_javascript(script, None, None, None) or False)

    def on_message(self, _ucm, result):
        try:
            payload = json.loads(result.get_js_value().to_string())
        except Exception:
            return
        action = payload.get("action")

        if action == "ready":
            threading.Thread(target=self._ocr_and_push, args=(2, False), daemon=True).start()
        elif action == "rescan":
            threading.Thread(target=self._ocr_and_push, args=(4, True), daemon=True).start()
        elif action == "copyImage":
            self._copy_image(payload["data"])
        elif action == "copyText":
            self._copy_text(payload["data"])
        elif action == "save":
            self._save(payload["data"])
        elif action == "close":
            Gtk.main_quit()

    def _ocr_and_push(self, scale, multi_psm):
        try:
            words, full_text = run_ocr(self.image_path, scale, multi_psm)
        except Exception:
            words, full_text = [], ""
        js_args = json.dumps(words) + "," + json.dumps(full_text)
        self.js(f"window.setOcrText({js_args});")

    def _png_bytes(self, b64data):
        return base64.b64decode(b64data)

    def _copy_image(self, b64data):
        data = self._png_bytes(b64data)
        subprocess.run(["wl-copy", "--type", "image/png"], input=data)

    def _copy_text(self, text):
        subprocess.run(["wl-copy"], input=text.encode("utf-8"))

    def _save(self, b64data):
        os.makedirs(SCREENSHOTS_DIR, exist_ok=True)
        data = self._png_bytes(b64data)

        dialog = Gtk.FileChooserDialog(
            title="บันทึกภาพหน้าจอ",
            parent=self.win,
            action=Gtk.FileChooserAction.SAVE,
        )
        dialog.add_buttons(
            Gtk.STOCK_CANCEL, Gtk.ResponseType.CANCEL,
            Gtk.STOCK_SAVE, Gtk.ResponseType.OK,
        )
        dialog.set_current_folder(SCREENSHOTS_DIR)
        dialog.set_current_name(datetime.now().strftime("%Y%m%d-%H%M%S") + ".png")
        dialog.set_do_overwrite_confirmation(True)

        png_filter = Gtk.FileFilter()
        png_filter.set_name("PNG image")
        png_filter.add_mime_type("image/png")
        png_filter.add_pattern("*.png")
        dialog.add_filter(png_filter)

        try:
            if dialog.run() == Gtk.ResponseType.OK:
                dest = dialog.get_filename()
                if not dest.lower().endswith(".png"):
                    dest += ".png"
                with open(dest, "wb") as f:
                    f.write(data)
                notify("บันทึกแล้ว", dest)
        finally:
            dialog.destroy()


def main():
    if len(sys.argv) < 2:
        print("usage: editor.py <image-path>", file=sys.stderr)
        sys.exit(1)
    image_path = os.path.abspath(sys.argv[1])
    if not os.path.isfile(image_path):
        print(f"no such file: {image_path}", file=sys.stderr)
        sys.exit(1)

    Editor(image_path)
    Gtk.main()


if __name__ == "__main__":
    main()

#!/usr/bin/env python3

from __future__ import annotations

import re
import subprocess
from ctypes import CDLL
from dataclasses import dataclass
from pathlib import Path

# Gtk4LayerShell must be loaded before GTK/libwayland when used through GI.
CDLL("libgtk4-layer-shell.so")

import gi

gi.require_version("Gdk", "4.0")
gi.require_version("GdkPixbuf", "2.0")
gi.require_version("Gtk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")

from gi.repository import Gdk, GdkPixbuf, Gio, GLib, Gtk, Gtk4LayerShell  # noqa: E402


APP_ID = "dev.siraxuth.ClipboardPicker"
IMAGE_RE = re.compile(r"binary.*?(jpg|jpeg|png|bmp)", re.IGNORECASE)
THUMBNAIL_DIR = Path.home() / ".cache" / "cliphist" / "thumbnails"
THUMBNAIL_SIZE = (256, 144)
FIRST_BATCH = 40
BATCH_SIZE = 60


@dataclass(slots=True)
class ClipItem:
    item_id: str
    preview: str
    image_extension: str | None

    @property
    def search_text(self) -> str:
        return self.preview.casefold()


def read_history() -> list[ClipItem]:
    result = subprocess.run(
        ["cliphist", "list"],
        check=False,
        capture_output=True,
        text=True,
        errors="replace",
    )
    items: list[ClipItem] = []
    for line in result.stdout.splitlines():
        item_id, separator, preview = line.partition("\t")
        if not separator or preview.startswith("<meta http-equiv="):
            continue
        match = IMAGE_RE.search(preview)
        items.append(
            ClipItem(
                item_id=item_id,
                preview=preview.replace("\n", " ").strip(),
                image_extension=match.group(1).lower() if match else None,
            )
        )
    return items


def _fit_thumbnail(loader: GdkPixbuf.PixbufLoader, width: int, height: int) -> None:
    max_width, max_height = THUMBNAIL_SIZE
    if width <= max_width and height <= max_height:
        return
    scale = min(max_width / width, max_height / height)
    loader.set_size(max(1, int(width * scale)), max(1, int(height * scale)))


def thumbnail_for(item: ClipItem) -> Path | None:
    if item.image_extension is None:
        return None

    THUMBNAIL_DIR.mkdir(parents=True, exist_ok=True)
    path = THUMBNAIL_DIR / f"{item.item_id}.png"
    if path.exists() and path.stat().st_size > 0:
        return path

    decoded = subprocess.run(
        ["cliphist", "decode"],
        input=item.item_id.encode(),
        check=False,
        capture_output=True,
    )
    if decoded.returncode != 0 or not decoded.stdout:
        return None

    # Store a downscaled copy: full-resolution clipboard images make opening
    # the picker cost seconds of decoding.
    loader = GdkPixbuf.PixbufLoader()
    loader.connect("size-prepared", _fit_thumbnail)
    try:
        loader.write(decoded.stdout)
        loader.close()
        pixbuf = loader.get_pixbuf()
    except GLib.Error:
        return None
    if pixbuf is None:
        return None

    pixbuf.savev(str(path), "png", [], [])
    return path


class ClipboardPicker(Gtk.Application):
    def __init__(self) -> None:
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.DEFAULT_FLAGS)
        self.window: Gtk.ApplicationWindow | None = None
        self.search: Gtk.SearchEntry | None = None
        self.counter: Gtk.Label | None = None
        self.list_box: Gtk.ListBox | None = None
        self.scroller: Gtk.ScrolledWindow | None = None
        self.items = read_history()
        self.pending: list[ClipItem] = []
        self.row_items: dict[Gtk.ListBoxRow, ClipItem] = {}
        self.query = ""

    def do_activate(self) -> None:
        if self.window is not None and self.window.get_visible():
            self.window.close()
            self.quit()
            return

        self._install_styles()
        self.window = Gtk.ApplicationWindow(application=self)
        self.window.set_title("Clipboard")
        self.window.set_decorated(False)
        self.window.set_resizable(False)
        self.window.set_default_size(860, 650)
        self.window.connect("close-request", self._on_close)

        Gtk4LayerShell.init_for_window(self.window)
        Gtk4LayerShell.set_namespace(self.window, "clipboard-picker")
        Gtk4LayerShell.set_layer(self.window, Gtk4LayerShell.Layer.OVERLAY)
        Gtk4LayerShell.set_keyboard_mode(
            self.window, Gtk4LayerShell.KeyboardMode.EXCLUSIVE
        )

        frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        frame.add_css_class("picker-frame")
        frame.set_size_request(860, 650)

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        header.add_css_class("picker-header")

        self.search = Gtk.SearchEntry()
        self.search.set_hexpand(True)
        self.search.set_placeholder_text("Search clipboard...")
        self.search.connect("search-changed", self._on_search_changed)
        self.search.connect("activate", lambda _entry: self._activate_selected())
        header.append(self.search)

        self.counter = Gtk.Label()
        self.counter.add_css_class("counter")
        header.append(self.counter)
        frame.append(header)

        self.list_box = Gtk.ListBox()
        self.list_box.add_css_class("history-list")
        self.list_box.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.list_box.set_activate_on_single_click(True)
        self.list_box.set_filter_func(self._filter_row)
        self.list_box.connect("row-activated", self._on_row_activated)

        if self.items:
            self._append_rows(self.items[:FIRST_BATCH])
            self.pending = self.items[FIRST_BATCH:]
        else:
            empty = Gtk.Label(label="Clipboard history is empty")
            empty.add_css_class("empty-state")
            empty.set_vexpand(True)
            self.list_box.append(empty)

        self.scroller = Gtk.ScrolledWindow()
        self.scroller.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.scroller.set_vexpand(True)
        self.scroller.set_child(self.list_box)
        frame.append(self.scroller)

        controller = Gtk.EventControllerKey()
        controller.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        controller.connect("key-pressed", self._on_key_pressed)
        self.window.add_controller(controller)

        self.window.set_child(frame)
        self._update_counter()
        self.window.present()
        self.search.grab_focus()
        GLib.idle_add(self._select_first)
        if self.pending:
            GLib.idle_add(self._append_pending_batch)

    def _append_rows(self, items: list[ClipItem]) -> None:
        if self.list_box is None:
            return
        for item in items:
            row = self._create_row(item)
            self.row_items[row] = item
            self.list_box.append(row)

    def _append_pending_batch(self) -> bool:
        # The remaining rows are added after the window is on screen, so opening
        # the picker does not wait on 750 widgets being built up front.
        batch, self.pending = self.pending[:BATCH_SIZE], self.pending[BATCH_SIZE:]
        self._append_rows(batch)
        self._update_counter()
        if self.pending:
            return GLib.SOURCE_CONTINUE
        if self.list_box is not None and self.list_box.get_selected_row() is None:
            self._select_first()
        return GLib.SOURCE_REMOVE

    def _install_styles(self) -> None:
        display = Gdk.Display.get_default()
        if display is None:
            return

        css = """
        window {
            background-color: transparent;
            color: #e4e1e7;
            font-family: "JetBrains Mono NF", monospace;
            font-size: 17px;
        }

        .picker-frame {
            background-color: rgba(19, 19, 23, 0.96);
            border: 2px solid rgba(186, 195, 255, 0.48);
            border-radius: 12px;
        }

        .picker-header {
            padding: 14px 18px 12px;
            border-bottom: 1px solid rgba(186, 195, 255, 0.16);
        }

        searchentry > text {
            min-height: 28px;
            padding: 5px 9px;
            color: #e4e1e7;
            background-color: rgba(255, 255, 255, 0.035);
            border: 0;
            border-radius: 8px;
            outline: 0;
            box-shadow: none;
        }

        searchentry > text:focus {
            background-color: rgba(186, 195, 255, 0.08);
        }

        .counter {
            min-width: 76px;
            color: #a9a9b3;
            font-size: 14px;
        }

        .history-list,
        .history-list > row {
            background-color: transparent;
        }

        .history-list > row {
            margin: 2px 10px;
            border-radius: 8px;
        }

        .history-list > row:selected {
            background-color: rgba(186, 195, 255, 0.42);
        }

        .row-content {
            padding-left: 14px;
            padding-right: 14px;
        }

        .text-row .row-content {
            min-height: 40px;
            padding-top: 2px;
            padding-bottom: 2px;
        }

        .image-row .row-content {
            min-height: 88px;
            padding-top: 6px;
            padding-bottom: 6px;
        }

        .clip-text {
            color: #e4e1e7;
        }

        .image-meta {
            color: #c8c5cc;
            font-size: 15px;
        }

        .thumbnail {
            background-color: rgba(255, 255, 255, 0.05);
            border-radius: 6px;
        }

        .empty-state {
            padding: 48px;
            color: #a9a9b3;
        }

        scrollbar slider {
            min-width: 5px;
            min-height: 36px;
            background-color: rgba(186, 195, 255, 0.32);
            border-radius: 3px;
        }
        """
        provider = Gtk.CssProvider()
        provider.load_from_string(css)
        Gtk.StyleContext.add_provider_for_display(
            display, provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def _create_row(self, item: ClipItem) -> Gtk.ListBoxRow:
        row = Gtk.ListBoxRow()
        content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=16)
        content.add_css_class("row-content")

        if item.image_extension is not None:
            row.add_css_class("image-row")
            path = thumbnail_for(item)
            if path is not None:
                picture = Gtk.Picture.new_for_filename(str(path))
                picture.add_css_class("thumbnail")
                picture.set_content_fit(Gtk.ContentFit.CONTAIN)
                picture.set_can_shrink(True)
                picture.set_size_request(128, 72)
                picture.set_alternative_text("Clipboard image preview")
                content.append(picture)

            label = Gtk.Label(label=self._image_label(item.preview))
            label.add_css_class("image-meta")
        else:
            row.add_css_class("text-row")
            label = Gtk.Label(label=item.preview)
            label.add_css_class("clip-text")

        label.set_hexpand(True)
        label.set_halign(Gtk.Align.START)
        label.set_xalign(0)
        label.set_ellipsize(3)
        label.set_single_line_mode(True)
        content.append(label)
        row.set_child(content)
        return row

    @staticmethod
    def _image_label(preview: str) -> str:
        details = preview.removeprefix("[[ ").removesuffix(" ]]")
        details = details.removeprefix("binary data ")
        return f"Image  ·  {details}"

    def _filter_row(self, row: Gtk.ListBoxRow) -> bool:
        item = self.row_items.get(row)
        return item is None or self.query in item.search_text

    def _matching_rows(self) -> list[Gtk.ListBoxRow]:
        return [
            row
            for row, item in self.row_items.items()
            if self.query in item.search_text
        ]

    def _on_search_changed(self, entry: Gtk.SearchEntry) -> None:
        self.query = entry.get_text().strip().casefold()
        if self.list_box is None:
            return
        self.list_box.invalidate_filter()
        self._update_counter()
        GLib.idle_add(self._select_first)

    def _update_counter(self) -> None:
        if self.counter is not None:
            self.counter.set_text(f"{len(self._matching_rows())}/{len(self.items)}")

    def _select_first(self) -> bool:
        if self.list_box is None:
            return GLib.SOURCE_REMOVE
        rows = self._matching_rows()
        self.list_box.select_row(rows[0] if rows else None)
        return GLib.SOURCE_REMOVE

    def _move_selection(self, amount: int) -> None:
        if self.list_box is None:
            return
        rows = self._matching_rows()
        if not rows:
            return
        selected = self.list_box.get_selected_row()
        try:
            index = rows.index(selected) if selected is not None else 0
        except ValueError:
            index = 0
        index = max(0, min(len(rows) - 1, index + amount))
        self.list_box.select_row(rows[index])
        rows[index].grab_focus()
        if self.search is not None:
            self.search.grab_focus()

    def _on_key_pressed(
        self,
        _controller: Gtk.EventControllerKey,
        keyval: int,
        _keycode: int,
        _state: Gdk.ModifierType,
    ) -> bool:
        if keyval == Gdk.KEY_Escape:
            if self.window is not None:
                self.window.close()
            self.quit()
            return True
        if keyval in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            self._activate_selected()
            return True
        if keyval == Gdk.KEY_Down:
            self._move_selection(1)
            return True
        if keyval == Gdk.KEY_Up:
            self._move_selection(-1)
            return True
        if keyval == Gdk.KEY_Page_Down:
            self._move_selection(6)
            return True
        if keyval == Gdk.KEY_Page_Up:
            self._move_selection(-6)
            return True
        if keyval == Gdk.KEY_Home:
            self._move_selection(-len(self.items))
            return True
        if keyval == Gdk.KEY_End:
            self._move_selection(len(self.items))
            return True
        return False

    def _activate_selected(self) -> None:
        if self.list_box is None:
            return
        row = self.list_box.get_selected_row()
        if row is None:
            rows = self._matching_rows()
            row = rows[0] if rows else None
        if row is not None:
            self._copy_item(self.row_items[row])

    def _on_row_activated(
        self, _list_box: Gtk.ListBox, row: Gtk.ListBoxRow
    ) -> None:
        item = self.row_items.get(row)
        if item is not None:
            self._copy_item(item)

    def _copy_item(self, item: ClipItem) -> None:
        decoded = subprocess.run(
            ["cliphist", "decode"],
            input=item.item_id.encode(),
            check=False,
            capture_output=True,
        )
        if decoded.returncode == 0:
            subprocess.run(["wl-copy"], input=decoded.stdout, check=False)
        if self.window is not None:
            self.window.close()
        self.quit()

    def _on_close(self, _window: Gtk.ApplicationWindow) -> bool:
        self.quit()
        return False


if __name__ == "__main__":
    raise SystemExit(ClipboardPicker().run())

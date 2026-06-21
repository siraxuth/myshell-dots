pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.utils

// Drives the existing `wallive` fish function (mpvpaper video wallpaper).
// QML never decodes video itself — keeps the leaky qs process clean.
//
// While a live wallpaper is active, caelestia's static wallpaper is switched to its
// transparent mode (background.wallpaperEnabled = false) so it is never seen and never
// occludes the video (even after a qs restart). Stopping restores it.
Singleton {
    id: root

    readonly property string dir: `${Paths.videos}/Wallpapers`
    readonly property string stateDir: `${Paths.home}/.config/wallive`
    readonly property string thumbDir: `${Paths.cache}/livewallpaper`

    property string current // path being shown right now (preview or committed; "" = none)
    property string committed // snapshot taken when the picker opens; Esc reverts to it
    property bool autostart // restore-on-login flag (wallive -s / -ns)
    property var videos: []
    property int thumbRev: 0 // bumped when first-frame thumbs finish generating

    function thumbPath(video: string): string {
        return `${root.thumbDir}/${video.split("/").pop()}.jpg`;
    }

    property bool thumbsDirty: false // videos changed while a thumb job was already running

    // POSIX-safe shell to generate a first-frame jpg for any video missing one.
    // -nostdin + </dev/null: qs connects a pipe to the process's stdin and ffmpeg
    // otherwise blocks reading it for interactive keys, so the job never finishes.
    function thumbScriptFor(vids: var): string {
        if (!vids.length)
            return "true";
        const q = s => "'" + s.replace(/'/g, "'\\''") + "'";
        let s = `mkdir -p ${q(root.thumbDir)}; `;
        for (const v of vids) {
            const t = q(root.thumbPath(v));
            s += `[ -s ${t} ] || ffmpeg -nostdin -y -ss 0 -i ${q(v)} -frames:v 1 -vf scale=480:-2 ${t} </dev/null >/dev/null 2>&1; `;
        }
        return s;
    }

    // Start a thumb job, or mark dirty if one is already running (so it reruns on exit).
    // Never toggles running=false on a live process: that kills ffmpeg mid-write and was
    // why thumbnails were not being generated.
    function genThumbs(): void {
        if (thumbProc.running) {
            root.thumbsDirty = true;
            return;
        }
        thumbProc.command = ["sh", "-c", root.thumbScriptFor(root.videos)];
        thumbProc.running = true;
    }

    // Apply a selection live. path === "" means stop / none.
    function apply(path: string): void {
        if (path) {
            Quickshell.execDetached(["fish", "-c", "wallive $argv[1]", path]);
            if (GlobalConfig.background.wallpaperEnabled)
                GlobalConfig.background.wallpaperEnabled = false;
            root.current = path;
        } else {
            Quickshell.execDetached(["fish", "-c", "wallive stop"]);
            if (!GlobalConfig.background.wallpaperEnabled)
                GlobalConfig.background.wallpaperEnabled = true;
            root.current = "";
        }
    }

    // Snapshot the current selection when the picker opens (Esc reverts to this).
    function snapshot(): void {
        root.committed = root.current;
    }

    // Keep whatever is currently previewed.
    function commit(): void {
        root.committed = root.current;
    }

    // Revert to the snapshot taken when the picker opened.
    function revert(): void {
        if (root.current !== root.committed)
            apply(root.committed);
    }

    function setAutostart(on: bool): void {
        Quickshell.execDetached(["fish", "-c", on ? "wallive -s" : "wallive -ns"]);
        root.autostart = on;
    }

    function refresh(): void {
        listProc.running = false;
        listProc.running = true;
    }

    // Coalesce bursts of inotify events (a single copy can fire several) into one refresh.
    Timer {
        id: watchDebounce

        interval: 400
        onTriggered: root.refresh()
    }

    // Watch the Wallpapers dir so videos dropped in while qs is running are picked up
    // automatically — refresh() rescans and onVideosChanged regenerates the missing
    // first-frame thumbs. close_write/moved_to fire only once the copy is complete, so
    // ffmpeg never reads a half-written file.
    Process {
        running: true
        command: ["sh", "-c", `mkdir -p "${root.dir}"; exec inotifywait -m -q -e close_write -e moved_to -e delete -e moved_from "${root.dir}"`]
        stdout: SplitParser {
            onRead: watchDebounce.restart()
        }
    }

    onVideosChanged: genThumbs()

    Component.onCompleted: refresh()

    Process {
        id: listProc

        command: ["sh", "-c", `find "${root.dir}" -maxdepth 1 -type f \\( -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' -o -iname '*.mov' -o -iname '*.avi' -o -iname '*.gif' \\) 2>/dev/null | sort`]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = text.trim() ? text.trim().split("\n") : [];
                // Only reassign when the list actually changed — a needless reassign rebuilds
                // the picker's tile Repeater and steals keyboard focus mid-session.
                if (JSON.stringify(next) !== JSON.stringify(root.videos))
                    root.videos = next;
            }
        }
    }

    // command is set imperatively by genThumbs() (not bound) so it never changes under a
    // running process — Quickshell would otherwise kill the job mid-write.
    Process {
        id: thumbProc

        onExited: {
            root.thumbRev++; // picker reloads previews for the freshly-written thumbs
            if (root.thumbsDirty) {
                root.thumbsDirty = false;
                root.genThumbs();
            }
        }
    }

    FileView {
        path: `${root.stateDir}/path`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.current = text().trim()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.current = "";
        }
    }

    FileView {
        path: `${root.stateDir}/autostart`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.autostart = true
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.autostart = false;
        }
    }
}

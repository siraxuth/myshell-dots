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

    // POSIX-safe shell to generate a first-frame jpg for any video missing one
    readonly property string thumbScript: {
        if (!videos.length)
            return "true";
        const q = s => "'" + s.replace(/'/g, "'\\''") + "'";
        let s = `mkdir -p ${q(root.thumbDir)}; `;
        for (const v of videos) {
            const t = q(root.thumbPath(v));
            s += `[ -s ${t} ] || ffmpeg -y -ss 0 -i ${q(v)} -frames:v 1 -vf scale=480:-2 ${t} >/dev/null 2>&1; `;
        }
        return s;
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

    onVideosChanged: {
        thumbProc.running = false;
        thumbProc.running = true;
    }

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

    Process {
        id: thumbProc

        command: ["sh", "-c", root.thumbScript]
        stdout: StdioCollector {
            onStreamFinished: root.thumbRev++
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

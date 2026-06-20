pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Tracks the workspace mode (separate per-monitor / shared) and toggles it by running
// scripts/workspace-mode.fish, which regenerates the sourced hypr conf and reloads Hyprland.
Singleton {
    id: root

    property string mode: "separate" // separate | shared

    function setMode(value: string): void {
        const next = value === "shared" ? "shared" : "separate";
        if (root.mode === next)
            return;
        root.mode = next;
        Quickshell.execDetached(["fish", `${Paths.home}/.local/share/caelestia/hypr/scripts/workspace-mode.fish`, next]);
    }

    FileView {
        path: `${Paths.config}/workspace-mode`
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.mode = text().trim() === "shared" ? "shared" : "separate"
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.mode = "separate";
        }
    }
}

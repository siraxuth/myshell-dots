pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    property string position: "bottom" // top | center | bottom — where the launcher sits
    property string searchPosition: "bottom" // top | bottom — where the search bar sits inside it

    function normalisePosition(value: string): string {
        if (value === "center")
            return "center";
        if (value === "top")
            return "top";
        return "bottom";
    }

    function normaliseSearchPosition(value: string): string {
        return value === "top" ? "top" : "bottom";
    }

    function persist(): void {
        storage.setText(JSON.stringify({
            position: root.position,
            searchPosition: root.searchPosition
        }, null, 2));
    }

    function setPosition(value: string): void {
        const next = normalisePosition(value);
        if (root.position === next)
            return;
        root.position = next;
        persist();
    }

    function setSearchPosition(value: string): void {
        const next = normaliseSearchPosition(value);
        if (root.searchPosition === next)
            return;
        root.searchPosition = next;
        persist();
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.config}/launcher-prefs.json`
        watchChanges: true
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.position = root.normalisePosition(data.position);
                root.searchPosition = root.normaliseSearchPosition(data.searchPosition);
            } catch (e) {
                root.position = "bottom";
                root.searchPosition = "bottom";
            }
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                Qt.callLater(() => root.persist());
        }
    }
}

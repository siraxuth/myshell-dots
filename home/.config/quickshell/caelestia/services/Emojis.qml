pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Emoji picker state + data (assets/emoji.json, generated from unicode emoji-test.txt).
Singleton {
    id: root

    property bool visible: false
    property var categories: []

    function copy(e: string): void {
        Quickshell.execDetached(["wl-copy", e]);
        root.visible = false;
    }

    function toggle(): void {
        root.visible = !root.visible;
    }

    FileView {
        path: Qt.resolvedUrl("../assets/emoji.json")
        printErrors: true
        onLoaded: {
            try {
                root.categories = JSON.parse(text());
            } catch (e) {}
        }
    }
}

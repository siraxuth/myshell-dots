pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    property string position: "left"

    function persist(): void {
        storage.setText(JSON.stringify({ position: root.position }, null, 2));
    }

    function setPosition(value: string): void {
        const next = BarPosition.resolvedPosition(value);
        if (root.position === next)
            return;
        root.position = next;
        persist();
    }

    FileView {
        id: storage

        path: `${Paths.config}/bar-position.json`
        watchChanges: true
        printErrors: false

        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                root.position = BarPosition.resolvedPosition(parsed?.position);
            } catch (e) {
                root.position = "left";
            }
        }

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                Qt.callLater(() => root.persist());
        }
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    property var enabledByScreen: ({})

    function isEnabledFor(name: string): bool {
        return root.enabledByScreen[name] ?? true;
    }

    function setEnabledFor(name: string, enabled: bool): void {
        const next = Object.assign({}, root.enabledByScreen);
        next[name] = enabled;
        root.enabledByScreen = next;
        persist();
    }

    function persist(): void {
        storage.setText(JSON.stringify(root.enabledByScreen, null, 2));
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.config}/desktop-clock-monitors.json`
        watchChanges: true
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data && typeof data === "object")
                    root.enabledByScreen = data;
            } catch (e) {
                root.enabledByScreen = ({});
            }
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                Qt.callLater(() => root.persist());
        }
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.utils

Singleton {
    id: root

    property real mouseSensitivity: 0

    function setMouseSensitivity(value: real): void {
        const next = Math.max(-1, Math.min(1, value));
        if (!Number.isFinite(next))
            return;

        mouseSensitivity = next;
        // Hyprland applies this keyword immediately; the JSON keeps it across logins.
        Hyprland.dispatch(`keyword input:sensitivity ${next.toFixed(2)}`);
        persistTimer.restart();
    }

    function persist(): void {
        storage.setText(JSON.stringify({
            mouseSensitivity: root.mouseSensitivity
        }, null, 2));
    }

    FileView {
        id: storage
        path: `${Paths.config}/input-prefs.json`
        printErrors: false
        watchChanges: true

        onLoaded: {
            try {
                const data = JSON.parse(text());
                const value = Number(data.mouseSensitivity ?? 0);
                root.mouseSensitivity = Number.isFinite(value) ? Math.max(-1, Math.min(1, value)) : 0;
                Hyprland.dispatch(`keyword input:sensitivity ${root.mouseSensitivity.toFixed(2)}`);
            } catch (error) {
                root.mouseSensitivity = 0;
            }
        }

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                Qt.callLater(root.persist);
        }
    }

    Timer {
        id: persistTimer
        interval: 180
        onTriggered: root.persist()
    }
}

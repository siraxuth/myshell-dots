pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Per-monitor enable flags for the hover/drag dashboard drawer. Stored as a map of
// screen name -> bool ("eDP-1": false). A monitor absent from the map defaults to ON,
// so new monitors show the dashboard until explicitly disabled. Read live from
// Interactions.qml's hover/drag handlers; toggled from the control-center Dashboard pane.
Singleton {
    id: root

    property var enabledByScreen: ({})

    function isEnabledFor(name: string): bool {
        return root.enabledByScreen[name] ?? true;
    }

    function setEnabledFor(name: string, on: bool): void {
        // Reassign a copy so property bindings (the settings switches) re-evaluate.
        const next = Object.assign({}, root.enabledByScreen);
        next[name] = on;
        root.enabledByScreen = next;
        persist();
    }

    function persist(): void {
        storage.setText(JSON.stringify(root.enabledByScreen, null, 2));
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.config}/dashboard-monitors.json`
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

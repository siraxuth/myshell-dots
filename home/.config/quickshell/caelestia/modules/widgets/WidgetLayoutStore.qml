pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

Item {
    id: root

    required property ShellScreen screen

    readonly property string monitorKey: WidgetsPrefs.safeName(screen.name)
    readonly property string directory: `${Paths.state}/widgets/${monitorKey}`
    readonly property string filePath: `${directory}/layout.json`
    readonly property string upstreamXdgStateHome: Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`
    readonly property string upstreamStateRoot: Quickshell.env("QS_STATE_DIR") || `${upstreamXdgStateHome}/serpantinum`
    readonly property string upstreamFilePath: `${upstreamStateRoot}/widgets/${monitorKey}/layout.json`
    property bool directoryReady: false
    property bool attemptedMigration: false
    property bool primaryMissing: false
    property bool upstreamReady: false
    property bool upstreamExists: false
    property var upstreamItems: []

    function finishMigration(): void {
        if (attemptedMigration || !primaryMissing || !WidgetsPrefs.legacyReady || !upstreamReady || !directoryReady)
            return;
        attemptedMigration = true;
        const items = upstreamExists ? WidgetsPrefs.normalizeLayout(upstreamItems) : WidgetsPrefs.migrateLegacy();
        WidgetsPrefs.setLoadedLayout(screen.name, items);
        layoutFile.setText(JSON.stringify(items, null, 2));
    }

    Process {
        id: createDirectory

        command: ["mkdir", "-p", root.directory]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                WidgetsPrefs.setSaveState(root.screen.name, "error");
                return;
            }
            root.directoryReady = true;
            layoutFile.reload();
        }
    }

    FileView {
        id: layoutFile

        printErrors: false
        watchChanges: false
        path: root.filePath

        onSaved: WidgetsPrefs.setSaveState(root.screen.name, "saved")
        onSaveFailed: error => WidgetsPrefs.setSaveState(root.screen.name, "error")
        onLoaded: {
            try {
                const parsed = JSON.parse(text());
                if (!Array.isArray(parsed))
                    throw new Error("Invalid widget layout");
                WidgetsPrefs.setLoadedLayout(root.screen.name, WidgetsPrefs.normalizeLayout(parsed));
                WidgetsPrefs.setSaveState(root.screen.name, "saved");
            } catch (error) {
                WidgetsPrefs.setSaveState(root.screen.name, "loadError");
            }
        }

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.primaryMissing = true;
                root.finishMigration();
            } else {
                WidgetsPrefs.setSaveState(root.screen.name, "loadError");
            }
        }
    }

    FileView {
        id: upstreamLayout
        printErrors: false
        watchChanges: false
        path: root.upstreamFilePath
        onLoaded: {
            root.upstreamExists = true;
            try {
                const parsed = JSON.parse(text());
                root.upstreamItems = Array.isArray(parsed) ? parsed : [];
            } catch (error) {
                root.upstreamItems = [];
            }
            root.upstreamReady = true;
            root.finishMigration();
        }
        onLoadFailed: error => {
            root.upstreamExists = false;
            root.upstreamReady = true;
            root.finishMigration();
        }
    }

    Connections {
        target: WidgetsPrefs

        function onRetrySave(screenName: string): void {
            if (screenName !== root.screen.name)
                return;
            if (!root.directoryReady)
                createDirectory.exec();
            else if (!WidgetsPrefs.isReady(screenName))
                layoutFile.reload();
            else {
                WidgetsPrefs.setSaveState(screenName, "saving");
                writeTimer.restart();
            }
        }

        function onLegacyReadyChanged(): void {
            root.finishMigration();
        }

        function onLayoutChanged(screenName: string): void {
            if (screenName === root.screen.name && WidgetsPrefs.isReady(screenName))
                writeTimer.restart();
        }
    }

    Timer {
        id: writeTimer

        interval: 180
        onTriggered: layoutFile.setText(JSON.stringify(WidgetsPrefs.layoutFor(root.screen.name), null, 2))
    }

    Component.onCompleted: createDirectory.exec(["mkdir", "-p", root.directory])
}

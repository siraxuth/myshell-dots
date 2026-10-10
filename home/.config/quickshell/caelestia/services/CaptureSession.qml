pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.services
import qs.utils

Singleton {
    id: root

    readonly property string helper: `${Paths.home}/.config/hypr/scripts/capture-dashboard/dashboard.py`
    property string manifestPath: ""
    property var manifest: ({})
    property var pendingRequest: ({})
    property bool preparing: false
    property bool dispatching: false

    function toggle(): void {
        if (preparing || dispatching)
            return;

        const visibilities = Visibilities.getForActive();
        if (visibilities?.capture)
            cancel();
        else
            prepare();
    }

    function prepare(): void {
        if (preparing || dispatching)
            return;
        preparing = true;
        prepareProcess.running = true;
    }

    function open(path: string): void {
        manifestPath = path;
        manifestFile.path = `file://${path}`;
    }

    function show(): void {
        const visibilities = Visibilities.getForActive();
        if (!visibilities) {
            discardSession();
            return;
        }

        visibilities.launcher = false;
        visibilities.dashboard = false;
        visibilities.liveWallpaper = false;
        visibilities.session = false;
        visibilities.sidebar = false;
        visibilities.utilities = false;
        visibilities.osd = false;
        visibilities.capture = true;
    }

    function cancel(): void {
        const visibilities = Visibilities.getForActive();
        if (visibilities)
            visibilities.capture = false;
        discardSession();
    }

    function discardSession(): void {
        const path = manifestPath;
        manifestPath = "";
        manifest = ({});
        if (path)
            Quickshell.execDetached(["/usr/bin/python3", helper, "cancel", path]);
    }

    function run(request: var): void {
        if (!manifestPath || dispatching)
            return;

        pendingRequest = request;
        dispatching = true;
        const visibilities = Visibilities.getForActive();
        if (visibilities)
            visibilities.capture = false;
        dispatchTimer.restart();
    }

    IpcHandler {
        target: "capture"

        function open(path: string): void {
            root.open(path);
        }

        function close(): void {
            root.cancel();
        }
    }

    FileView {
        id: manifestFile

        printErrors: false
        watchChanges: false
        onLoaded: {
            try {
                root.manifest = JSON.parse(text());
                root.show();
            } catch (error) {
                console.warn("Unable to read capture session:", error);
                root.cancel();
            }
        }
        onLoadFailed: error => {
            console.warn("Unable to load capture session:", error);
            root.cancel();
        }
    }

    Process {
        id: prepareProcess

        command: ["/usr/bin/python3", root.helper, "prepare"]
        onExited: (code, status) => {
            root.preparing = false;
            if (code !== 0)
                Quickshell.execDetached(["notify-send", "Capture unavailable", "Could not prepare a desktop snapshot."]);
        }
    }

    Process {
        id: dispatchProcess

        command: ["/usr/bin/python3", root.helper, "dispatch", root.manifestPath, JSON.stringify(root.pendingRequest)]
        onExited: (code, status) => {
            const path = root.manifestPath;
            root.manifestPath = "";
            root.manifest = ({});
            root.dispatching = false;
            if (code !== 0) {
                Quickshell.execDetached(["/usr/bin/python3", root.helper, "cancel", path]);
                Quickshell.execDetached(["notify-send", "Capture failed", "The selected screen capture could not be completed."]);
            }
        }
    }

    Timer {
        id: dispatchTimer

        interval: 120
        onTriggered: dispatchProcess.running = true
    }
}

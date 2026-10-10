pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.utils

Singleton {
    id: root

    signal startupRefreshFinished()

    readonly property string helper: `${Quickshell.shellDir}/modules/taskmanager/taskmanager.py`
    property bool visible: false
    property string screenName: ""
    property string activeTab: "processes"
    property string searchText: ""
    property string sortKey: "rss"
    property var snapshot: ({ memTotal: 0, memUsed: 0, memCached: 0, swapTotal: 0, swapUsed: 0, cpu: 0, cores: 1, procs: [] })
    property var startupEntries: []
    property bool startupLoading: false
    property bool startupLoaded: false
    property bool actionPending: false
    property string message: ""
    property bool messageError: false
    property int pendingPid: -1
    property int pendingStartTicks: -1
    property bool pendingForce: false

    readonly property var filteredProcesses: {
        const query = searchText.trim().toLowerCase();
        const rows = (snapshot.procs ?? []).filter(proc => !query || proc.name.toLowerCase().includes(query)
            || proc.cmd.toLowerCase().includes(query) || String(proc.pid) === query);
        const key = sortKey;
        rows.sort((a, b) => (b[key] - a[key]) || (b.rss - a.rss));
        return rows;
    }

    function open(): void {
        screenName = Hypr.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
        visible = true;
        activeTab = "processes";
        searchText = "";
        message = "";
        refreshStartup();
    }

    function close(): void {
        visible = false;
        searchText = "";
        pendingPid = -1;
        pendingStartTicks = -1;
        pendingForce = false;
    }

    function toggle(): void {
        if (visible)
            close();
        else
            open();
    }

    function refreshStartup(): void {
        startupLoading = !startupLoaded;
        startupQuery.running = false;
        startupQuery.running = true;
    }

    function setStartup(id: string, enabled: bool): void {
        if (actionPending)
            return;
        actionPending = true;
        operationPurpose = "startup";
        operation.command = ["python3", helper, "set-startup", id, enabled ? "true" : "false"];
        operation.running = true;
    }

    function requestEnd(pid: int, startTicks: int, force: bool): void {
        if (actionPending)
            return;
        pendingPid = pid;
        pendingStartTicks = startTicks;
        pendingForce = force;
        actionPending = true;
        operationPurpose = "process";
        operation.command = ["python3", helper, "end", String(pid), String(startTicks), force ? "true" : "false"];
        operation.running = true;
    }

    function applyOperation(text: string): void {
        actionPending = false;
        let result;
        try {
            result = JSON.parse(text);
        } catch (error) {
            message = qsTr("The system returned an unreadable response.");
            messageError = true;
            return;
        }
        message = result.message ?? "";
        messageError = !result.ok;
        if (operationPurpose === "startup")
            refreshStartup();
    }

    IpcHandler {
        target: "taskManager"
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function toggle(): void { root.toggle(); }
    }

    Process {
        id: feed
        command: ["python3", root.helper, "monitor", "1"]
        running: root.visible
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.snapshot = JSON.parse(line);
                } catch (error) {
                    console.warn("Task Manager received invalid process data", error);
                }
            }
        }
        stderr: SplitParser {
            onRead: line => console.warn("Task Manager process monitor:", line)
        }
    }

    Process {
        id: startupQuery
        command: ["python3", root.helper, "startup"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.startupLoading = false;
                root.startupLoaded = true;
                try {
                    const result = JSON.parse(text);
                    root.startupEntries = result.entries ?? [];
                    root.message = (result.warnings ?? []).join(" · ");
                    root.messageError = (result.warnings ?? []).length > 0;
                    if (!result.ok) {
                        root.message = result.message ?? qsTr("Could not read startup entries.");
                        root.messageError = true;
                    }
                    root.startupRefreshFinished();
                } catch (error) {
                    root.startupEntries = [];
                    root.message = qsTr("Could not read startup entries.");
                    root.messageError = true;
                    root.startupRefreshFinished();
                }
            }
        }
    }

    property string operationPurpose: ""
    Process {
        id: operation
        command: []
        stdout: StdioCollector {
            onStreamFinished: root.applyOperation(text)
        }
        stderr: SplitParser {
            onRead: line => console.warn("Task Manager action:", line)
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            if (root.visible && !Quickshell.screens.some(screen => screen.name === root.screenName))
                root.close();
        }
    }
}

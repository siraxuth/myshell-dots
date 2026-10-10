pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Scope {
    id: root

    property int confirmPid: -1
    property int forceConfirmPid: -1
    property int waitingPid: -1
    property int waitingStartTicks: -1
    property real startupScrollY: 0

    function close(): void {
        confirmPid = -1;
        forceConfirmPid = -1;
        waitingPid = -1;
        TaskManagerService.close();
    }

    Loader {
        active: TaskManagerService.visible && Quickshell.screens.some(screen => screen.name === TaskManagerService.screenName)
        sourceComponent: PanelWindow {
            id: window

            readonly property ShellScreen targetScreen: Quickshell.screens.find(screen => screen.name === TaskManagerService.screenName) ?? null
            screen: targetScreen
            visible: TaskManagerService.visible
            color: "transparent"
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            WlrLayershell.namespace: "caelestia-task-manager"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            Rectangle {
                id: scrim
                anchors.fill: parent
                color: Colours.palette.m3scrim
                opacity: 0.48

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.close()
                }
            }

            StyledRect {
                id: panel
                anchors.centerIn: parent
                width: Math.min(900, parent.width - 32)
                height: Math.min(760, parent.height - 32)
                radius: Tokens.rounding.large
                color: Colours.palette.m3surfaceContainer
                border.width: 1
                border.color: Colours.palette.m3outlineVariant
                focus: true

                // Keep clicks on the panel's empty spacing from reaching the
                // full-screen scrim, which intentionally dismisses on outside clicks.
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onClicked: {}
                }

                Keys.onEscapePressed: {
                    if (TaskManagerService.searchText.length > 0) {
                        TaskManagerService.searchText = "";
                        searchField.clear();
                    } else {
                        root.close();
                    }
                }
                Keys.onPressed: event => {
                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
                        searchField.forceActiveFocus();
                        event.accepted = true;
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.normal

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.normal

                        StyledRect {
                            implicitWidth: 44
                            implicitHeight: 44
                            radius: Tokens.rounding.normal
                            color: Colours.palette.m3primaryContainer
                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "monitor_heart"
                                color: Colours.palette.m3onPrimaryContainer
                                font.pointSize: Tokens.font.size.large
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            StyledText {
                                text: qsTr("Task Manager")
                                font.pointSize: Tokens.font.size.large
                                font.weight: Font.DemiBold
                            }
                            StyledText {
                                text: qsTr("Processes and startup apps")
                                color: Colours.palette.m3onSurfaceVariant
                                font.pointSize: Tokens.font.size.small
                            }
                        }

                        StyledRect {
                            implicitWidth: processCount.implicitWidth + Tokens.padding.normal * 2
                            implicitHeight: processCount.implicitHeight + Tokens.padding.small * 2
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3surfaceContainerHigh
                            StyledText {
                                id: processCount
                                anchors.centerIn: parent
                                text: qsTr("%1 processes").arg(TaskManagerService.snapshot.procs?.length ?? 0)
                                color: Colours.palette.m3onSurfaceVariant
                                font.pointSize: Tokens.font.size.small
                            }
                        }

                        IconButton {
                            icon: "close"
                            type: IconButton.Text
                            Accessible.name: qsTr("Close Task Manager")
                            onClicked: root.close()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small
                        TextButton {
                            text: qsTr("Processes")
                            type: TaskManagerService.activeTab === "processes" ? TextButton.Filled : TextButton.Tonal
                            checked: TaskManagerService.activeTab === "processes"
                            onClicked: {
                                TaskManagerService.activeTab = "processes";
                                TaskManagerService.searchText = "";
                                searchField.clear();
                            }
                        }
                        TextButton {
                            text: qsTr("Startup apps")
                            type: TaskManagerService.activeTab === "startup" ? TextButton.Filled : TextButton.Tonal
                            checked: TaskManagerService.activeTab === "startup"
                            onClicked: {
                                TaskManagerService.activeTab = "startup";
                                TaskManagerService.searchText = "";
                                searchField.clear();
                                TaskManagerService.refreshStartup();
                            }
                        }
                        Item { Layout.fillWidth: true }
                        TextButton {
                            visible: TaskManagerService.activeTab === "startup"
                            text: "refresh"
                            type: TextButton.Text
                            Accessible.name: qsTr("Refresh startup list")
                            onClicked: {
                                root.startupScrollY = startupList.contentY;
                                TaskManagerService.refreshStartup();
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: TaskManagerService.activeTab === "processes"
                        spacing: Tokens.spacing.small

                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: 54
                            radius: Tokens.rounding.normal
                            color: Colours.palette.m3surfaceContainerHigh
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Tokens.padding.normal
                                StyledText {
                                    Layout.fillWidth: true
                                    text: qsTr("Memory")
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                                StyledText {
                                    text: `${TaskManagerService.snapshot.memTotal > 0 ? Math.round(TaskManagerService.snapshot.memUsed / TaskManagerService.snapshot.memTotal * 100) : 0}%  ·  ${root.formatBytes(TaskManagerService.snapshot.memUsed)} / ${root.formatBytes(TaskManagerService.snapshot.memTotal)}`
                                    font.pointSize: Tokens.font.size.small
                                }
                            }
                        }
                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: 54
                            radius: Tokens.rounding.normal
                            color: Colours.palette.m3surfaceContainerHigh
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Tokens.padding.normal
                                StyledText { Layout.fillWidth: true; text: qsTr("CPU"); color: Colours.palette.m3onSurfaceVariant }
                                StyledText { text: `${TaskManagerService.snapshot.cpu ?? 0}%`; font.pointSize: Tokens.font.size.small }
                            }
                        }
                        StyledRect {
                            Layout.fillWidth: true
                            implicitHeight: 54
                            radius: Tokens.rounding.normal
                            color: Colours.palette.m3surfaceContainerHigh
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Tokens.padding.normal
                                StyledText { Layout.fillWidth: true; text: qsTr("Swap"); color: Colours.palette.m3onSurfaceVariant }
                                StyledText {
                                    text: `${root.formatBytes(TaskManagerService.snapshot.swapUsed)} / ${root.formatBytes(TaskManagerService.snapshot.swapTotal)}`
                                    font.pointSize: Tokens.font.size.small
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledTextField {
                            id: searchField
                            Layout.fillWidth: true
                            placeholderText: TaskManagerService.activeTab === "processes"
                                ? qsTr("Search process name, command or PID") : qsTr("Search startup app, service or command")
                            Accessible.name: placeholderText
                            onTextChanged: TaskManagerService.searchText = text
                            Keys.onDownPressed: {
                                processList.forceActiveFocus();
                                processList.currentIndex = 0;
                            }
                        }
                        TextButton {
                            visible: TaskManagerService.activeTab === "processes"
                            text: TaskManagerService.sortKey === "rss" ? qsTr("Memory ↓") : qsTr("Memory")
                            type: TaskManagerService.sortKey === "rss" ? TextButton.Tonal : TextButton.Text
                            onClicked: TaskManagerService.sortKey = "rss"
                        }
                        TextButton {
                            visible: TaskManagerService.activeTab === "processes"
                            text: TaskManagerService.sortKey === "cpu" ? qsTr("CPU ↓") : qsTr("CPU")
                            type: TaskManagerService.sortKey === "cpu" ? TextButton.Tonal : TextButton.Text
                            onClicked: TaskManagerService.sortKey = "cpu"
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: TaskManagerService.activeTab === "processes"
                        Layout.leftMargin: Tokens.padding.normal
                        Layout.rightMargin: Tokens.padding.normal
                        StyledText { Layout.fillWidth: true; text: qsTr("PROCESS"); color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.font.size.smaller }
                        StyledText { Layout.preferredWidth: 72; horizontalAlignment: Text.AlignRight; text: "PID"; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.font.size.smaller }
                        StyledText { Layout.preferredWidth: 92; horizontalAlignment: Text.AlignRight; text: qsTr("MEMORY"); color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.font.size.smaller }
                        StyledText { Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight; text: qsTr("CPU"); color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.font.size.smaller }
                        Item { Layout.preferredWidth: 112 }
                    }

                    ListView {
                        id: processList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: TaskManagerService.activeTab === "processes"
                        clip: true
                        spacing: Tokens.spacing.smaller
                        model: TaskManagerService.filteredProcesses
                        boundsBehavior: Flickable.StopAtBounds
                        keyNavigationEnabled: true
                        highlightFollowsCurrentItem: false

                        StyledText {
                            anchors.centerIn: parent
                            visible: processList.count === 0
                            text: qsTr("No matching processes")
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        delegate: StyledRect {
                            id: row
                            required property int index
                            required property int pid
                            required property string name
                            required property string cmd
                            required property real rss
                            required property real cpu
                            required property int startTicks
                            required property bool killAllowed

                            width: processList.width
                            height: 52
                            radius: Tokens.rounding.small
                            color: processList.currentIndex === index && processList.activeFocus
                                ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh
                            activeFocusOnTab: true
                            Accessible.role: Accessible.ListItem
                            Accessible.name: `${name}, PID ${pid}, ${root.formatBytes(rss)}, ${cpu}% CPU`
                            Keys.onReturnPressed: processList.currentIndex = index
                            Keys.onEnterPressed: processList.currentIndex = index
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Space && killAllowed) {
                                    root.confirmPid = pid;
                                    event.accepted = true;
                                }
                            }

                            StateLayer { radius: parent.radius; onClicked: processList.currentIndex = index }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.normal
                                anchors.rightMargin: Tokens.padding.small
                                spacing: Tokens.spacing.small
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    StyledText { Layout.fillWidth: true; text: row.name; elide: Text.ElideRight; font.weight: Font.Medium }
                                    StyledText { Layout.fillWidth: true; text: row.cmd; elide: Text.ElideMiddle; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.font.size.smaller }
                                }
                                StyledText { Layout.preferredWidth: 72; horizontalAlignment: Text.AlignRight; text: row.pid; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.font.size.small }
                                StyledText { Layout.preferredWidth: 92; horizontalAlignment: Text.AlignRight; text: root.formatBytes(row.rss); font.pointSize: Tokens.font.size.small }
                                StyledText { Layout.preferredWidth: 70; horizontalAlignment: Text.AlignRight; text: `${row.cpu.toFixed(1)}%`; color: row.cpu > 25 ? Colours.palette.m3tertiary : Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.font.size.small }

                                TextButton {
                                    Layout.preferredWidth: 112
                                    text: !row.killAllowed ? qsTr("Protected")
                                        : root.forceConfirmPid === row.pid ? qsTr("Confirm force")
                                        : root.waitingPid === row.pid ? qsTr("Force quit")
                                        : root.confirmPid === row.pid ? qsTr("Confirm close") : qsTr("End task")
                                    type: root.forceConfirmPid === row.pid || root.waitingPid === row.pid || root.confirmPid === row.pid
                                        ? TextButton.Tonal : TextButton.Text
                                    enabled: row.killAllowed && !TaskManagerService.actionPending
                                    Accessible.name: text + ` ${row.name}`
                                    onClicked: {
                                        if (root.forceConfirmPid === row.pid) {
                                            TaskManagerService.requestEnd(row.pid, row.startTicks, true);
                                            root.forceConfirmPid = -1;
                                            root.waitingPid = -1;
                                        } else if (root.waitingPid === row.pid) {
                                            root.forceConfirmPid = row.pid;
                                        } else if (root.confirmPid === row.pid) {
                                            TaskManagerService.requestEnd(row.pid, row.startTicks, false);
                                            root.waitingPid = row.pid;
                                            root.waitingStartTicks = row.startTicks;
                                            root.confirmPid = -1;
                                            forceCheck.restart();
                                        } else {
                                            root.confirmPid = row.pid;
                                            confirmTimeout.restart();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        id: startupView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: TaskManagerService.activeTab === "startup"
                        spacing: Tokens.spacing.small

                        RowLayout {
                            Layout.fillWidth: true
                            StyledText { Layout.fillWidth: true; text: qsTr("STARTUP ITEM"); color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.font.size.smaller }
                            StyledText { Layout.preferredWidth: 170; text: qsTr("SOURCE"); color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.font.size.smaller }
                            StyledText { Layout.preferredWidth: 140; horizontalAlignment: Text.AlignRight; text: qsTr("START WITH SESSION"); color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.font.size.smaller }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: TaskManagerService.startupLoading || (TaskManagerService.startupLoaded && TaskManagerService.startupEntries.length === 0)
                            StyledText {
                                anchors.centerIn: parent
                                width: parent.width - Tokens.padding.large * 2
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                color: Colours.palette.m3onSurfaceVariant
                                text: TaskManagerService.startupLoading ? qsTr("Reading startup sources…") : qsTr("No startup entries found.")
                            }
                        }

                        ListView {
                            id: startupList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: TaskManagerService.startupLoaded && TaskManagerService.startupEntries.length > 0
                            clip: true
                            spacing: Tokens.spacing.smaller
                            model: TaskManagerService.startupEntries.filter(entry => {
                                const query = TaskManagerService.searchText.trim().toLowerCase();
                                return !query || entry.name.toLowerCase().includes(query) || entry.exec.toLowerCase().includes(query) || entry.source.toLowerCase().includes(query);
                            })

                            StyledText {
                                anchors.centerIn: parent
                                visible: startupList.count === 0 && !TaskManagerService.startupLoading
                                text: qsTr("No matching startup entries")
                                color: Colours.palette.m3onSurfaceVariant
                            }

                            delegate: StyledRect {
                                required property var modelData
                                width: ListView.view.width
                                height: 64
                                radius: Tokens.rounding.small
                                color: Colours.palette.m3surfaceContainerHigh

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Tokens.padding.normal
                                    anchors.rightMargin: Tokens.padding.normal
                                    spacing: Tokens.spacing.normal

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        StyledText { Layout.fillWidth: true; text: modelData.name; elide: Text.ElideRight; font.weight: Font.Medium }
                                        StyledText { Layout.fillWidth: true; text: modelData.exec; elide: Text.ElideMiddle; color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.font.size.smaller }
                                    }
                                    StyledText {
                                        Layout.preferredWidth: 170
                                        text: modelData.source
                                        color: Colours.palette.m3onSurfaceVariant
                                        font.pointSize: Tokens.font.size.small
                                    }
                                    ColumnLayout {
                                        Layout.preferredWidth: 140
                                        RowLayout {
                                            Layout.alignment: Qt.AlignRight
                                            spacing: Tokens.spacing.smaller
                                            StyledRect {
                                                implicitWidth: runningLabel.implicitWidth + Tokens.padding.small * 2
                                                implicitHeight: runningLabel.implicitHeight + Tokens.padding.smaller * 2
                                                visible: modelData.running
                                                radius: Tokens.rounding.full
                                                color: Colours.palette.m3successContainer
                                                StyledText { id: runningLabel; anchors.centerIn: parent; text: qsTr("Running"); color: Colours.palette.m3onSuccessContainer; font.pointSize: Tokens.font.size.smaller }
                                            }
                                            StyledSwitch {
                                                checked: modelData.enabled
                                                enabled: !TaskManagerService.actionPending && modelData.manageable !== false
                                                Accessible.name: qsTr("Start %1 with the session").arg(modelData.name)
                                                onToggled: {
                                                    root.startupScrollY = startupList.contentY;
                                                    TaskManagerService.setStartup(modelData.id, checked);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    StyledRect {
                        Layout.fillWidth: true
                        implicitHeight: statusText.implicitHeight + Tokens.padding.small * 2
                        visible: TaskManagerService.message.length > 0
                        radius: Tokens.rounding.small
                        color: TaskManagerService.messageError ? Colours.palette.m3errorContainer : Colours.palette.m3secondaryContainer
                        StyledText {
                            id: statusText
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.small
                            text: TaskManagerService.message
                            wrapMode: Text.Wrap
                            color: TaskManagerService.messageError ? Colours.palette.m3onErrorContainer : Colours.palette.m3onSecondaryContainer
                            font.pointSize: Tokens.font.size.small
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: TaskManagerService.activeTab === "processes"
                                ? qsTr("Select a process to end it. Critical system tasks are protected.")
                                : qsTr("Changes apply now and when you sign in again.")
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Tokens.font.size.small
                        }
                        TextButton { text: qsTr("Close"); type: TextButton.Tonal; onClicked: root.close() }
                    }
                }
            }

            Timer {
                id: confirmTimeout
                interval: 3500
                onTriggered: root.confirmPid = -1
            }
            Timer {
                id: forceCheck
                interval: 2200
                onTriggered: {
                    const stillRunning = TaskManagerService.snapshot.procs.some(proc => proc.pid === root.waitingPid && proc.startTicks === root.waitingStartTicks);
                    if (!stillRunning)
                        root.waitingPid = -1;
                }
            }

            Connections {
                target: TaskManagerService
                function onStartupRefreshFinished(): void {
                    Qt.callLater(() => {
                        startupList.contentY = Math.min(root.startupScrollY, Math.max(0, startupList.contentHeight - startupList.height));
                    });
                }
            }

            Component.onCompleted: Qt.callLater(() => searchField.forceActiveFocus())
        }
    }

    function formatBytes(bytes: real): string {
        if (!Number.isFinite(bytes) || bytes <= 0)
            return "0 MB";
        if (bytes >= 1024 ** 3)
            return `${(bytes / (1024 ** 3)).toFixed(1)} GB`;
        if (bytes >= 1024 ** 2)
            return `${Math.round(bytes / (1024 ** 2))} MB`;
        return `${Math.round(bytes / 1024)} KB`;
    }
}

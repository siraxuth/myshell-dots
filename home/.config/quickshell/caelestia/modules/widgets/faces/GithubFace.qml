pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls

Item {
    id: root

    required property var widget
    property int contributionCount: -1
    property string errorText: ""
    property string lastUsername: ""
    property var contributions: []
    property int currentYear: new Date().getFullYear()
    property int selectedYear: new Date().getFullYear()
    readonly property color textColor: {
        const value = String(widget.wProps?.textColor ?? "").trim().toLowerCase();
        if (value === "primary") return Colours.palette.m3primary;
        if (value === "secondary") return Colours.palette.m3secondary;
        if (value === "tertiary") return Colours.palette.m3tertiary;
        if (/^#[0-9a-f]{6}$/i.test(value)) return Qt.color(value);
        return Colours.palette.m3onSurface;
    }

    function checkUsername(): void {
        const username = String(widget.wProps?.username ?? "").trim();
        if (username === lastUsername)
            return;
        lastUsername = username;
        refresh();
    }

    function refresh(): void {
        const username = lastUsername;
        if (!username) {
            errorText = qsTr("Set a GitHub username in Control Center")
            contributionCount = -1;
            return;
        }
        refreshDelay.restart();
    }

    function requestData(): void {
        const username = lastUsername;
        if (!username)
            return;
        const yearQuery = selectedYear === currentYear ? "last" : String(selectedYear);
        request.command = ["curl", "--fail", "--silent", "--show-error", "--max-time", "8", `https://github-contributions-api.jogruber.de/v4/${encodeURIComponent(username)}?y=${yearQuery}`];
        request.running = true;
        errorText = "";
    }

    function contributionColor(day: var): color {
        const count = Number(day?.count ?? 0);
        if (count <= 0)
            return Colours.layer(Colours.palette.m3surface, 2);

        const suppliedLevel = Number(day?.level);
        const level = Number.isFinite(suppliedLevel) && suppliedLevel > 0
            ? Math.min(4, Math.round(suppliedLevel))
            : count === 1 ? 1 : count <= 3 ? 2 : count <= 6 ? 3 : 4;
        return ["#161b22", "#0e4429", "#006d32", "#26a641", "#39d353"][level];
    }

    Process {
        id: request
        property string output: ""
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => request.output += data
        }
        onRunningChanged: if (running) output = ""
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.errorText = qsTr("GitHub data is unavailable")
                root.contributionCount = -1;
                return;
            }
            try {
                const payload = JSON.parse(output);
                root.contributions = payload.contributions ?? [];
                root.contributionCount = payload.total?.[root.selectedYear] ?? (root.selectedYear === root.currentYear ? payload.total?.lastYear : undefined) ?? root.contributions.reduce((sum, day) => sum + Number(day.count ?? 0), 0);
                root.errorText = "";
            } catch (error) {
                root.errorText = qsTr("Could not read GitHub data")
                root.contributionCount = -1;
            }
        }
    }

    Component.onCompleted: checkUsername()
    onWidgetChanged: checkUsername()

    Timer { id: refreshDelay; interval: 450; onTriggered: root.requestData() }
    Timer { interval: 3600000; repeat: true; running: true; onTriggered: root.requestData() }

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: "transparent"
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.small
            RowLayout {
                Layout.fillWidth: true
                MaterialIcon { text: "code"; color: Colours.palette.m3primary }
                StyledText {
                    Layout.fillWidth: true
                    text: root.widget.wProps?.username ? `@${root.widget.wProps.username}` : "GitHub"
                    color: root.textColor
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                IconButton { icon: "chevron_left"; disabled: root.selectedYear <= 2008; onClicked: { root.selectedYear--; root.requestData(); } }
                StyledText { text: String(root.selectedYear); color: root.textColor; font.bold: true }
                IconButton { icon: "chevron_right"; disabled: root.selectedYear >= root.currentYear; onClicked: { root.selectedYear++; root.requestData(); } }
            }
            StyledText {
                visible: root.contributionCount >= 0
                text: qsTr("%1 contributions").arg(root.contributionCount)
                color: root.textColor
                font.pointSize: Tokens.font.size.small
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.contributionCount < 0
                text: root.errorText
                color: Qt.alpha(root.textColor, 0.72)
                font.pointSize: Tokens.font.size.small
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                columns: 53
                rowSpacing: 3
                columnSpacing: 3
                Repeater {
                    model: root.contributions
                    Rectangle {
                        required property var modelData
                        readonly property int count: Number(modelData.count ?? 0)
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 3
                        Layout.minimumHeight: 4
                        radius: 2
                        color: root.contributionColor(modelData)
                        opacity: root.contributionCount < 0 ? 0.35 : 1
                        ToolTip.visible: cellMouse.containsMouse
                        ToolTip.text: `${modelData.date}: ${count} ${qsTr("contributions")}`
                        MouseArea { id: cellMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                    }
                }
            }
        }
    }
}

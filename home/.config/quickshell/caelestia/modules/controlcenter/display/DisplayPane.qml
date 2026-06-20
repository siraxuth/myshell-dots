pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property Session session

    readonly property var mons: Displays.monitors
    readonly property var primary: mons.find(m => m.focused) ?? (mons.length > 0 ? mons[0] : null)
    property string arrangeMode: "extend" // extend | mirror | single
    property string secondPos: "below" // right | left | above | below (relative to primary)
    property bool initialised: false

    function res(m: var): string {
        return `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}`;
    }
    function effW(m: var): int {
        return Math.round(m.width / m.scale);
    }
    function effH(m: var): int {
        return Math.round(m.height / m.scale);
    }

    // Pick a sensible initial "second screen position" from the current layout.
    function detectPos(): void {
        if (initialised || !primary || mons.length < 2)
            return;
        const sec = mons.find(m => m.name !== primary.name);
        if (!sec)
            return;
        if (sec.y > primary.y)
            secondPos = "below";
        else if (sec.y < primary.y)
            secondPos = "above";
        else if (sec.x > primary.x)
            secondPos = "right";
        else
            secondPos = "left";
        initialised = true;
    }

    function buildLines(): var {
        if (!primary)
            return [];
        const others = mons.filter(m => m.name !== primary.name);
        const lines = [];
        if (arrangeMode === "single") {
            lines.push(`monitor=${primary.name},${res(primary)},0x0,${primary.scale}`);
            for (const m of others)
                lines.push(`monitor=${m.name},disable`);
        } else if (arrangeMode === "mirror") {
            lines.push(`monitor=${primary.name},${res(primary)},0x0,${primary.scale}`);
            for (const m of others)
                lines.push(`monitor=${m.name},${res(m)},0x0,${m.scale},mirror,${primary.name}`);
        } else {
            const pw = effW(primary);
            const ph = effH(primary);
            const sec = others[0];
            let px = 0, py = 0, secPos = "0x0";
            if (sec) {
                const sw = effW(sec);
                const sh = effH(sec);
                if (secondPos === "right") {
                    px = 0; secPos = `${pw}x0`;
                } else if (secondPos === "left") {
                    px = sw; secPos = `0x0`;
                } else if (secondPos === "above") {
                    py = sh; secPos = `0x0`;
                } else {
                    secPos = `0x${ph}`;
                }
            }
            lines.push(`monitor=${primary.name},${res(primary)},${px}x${py},${primary.scale}`);
            others.forEach((m, i) => {
                if (i === 0)
                    lines.push(`monitor=${m.name},${res(m)},${secPos},${m.scale}`);
                else
                    lines.push(`monitor=${m.name},${res(m)},${px + pw + i * 64}x0,${m.scale}`); // 3rd+ : tack on to the right
            });
        }
        return lines;
    }

    Component.onCompleted: Qt.callLater(detectPos)

    Connections {
        target: Displays
        function onMonitorsChanged(): void {
            root.detectPos();
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: layout.implicitHeight + Tokens.padding.large * 2
        clip: true

        ColumnLayout {
            id: layout

            x: Tokens.padding.large
            y: Tokens.padding.large
            width: parent.width - Tokens.padding.large * 2
            spacing: Tokens.spacing.normal

            SettingsHeader {
                icon: "desktop_windows"
                title: qsTr("Display & Workspaces")
            }

            // ── Monitors ──────────────────────────────────────────────────
            SectionHeader {
                Layout.topMargin: Tokens.spacing.large
                title: qsTr("Monitors")
                description: qsTr("Arrange your screens — applied to monitors.conf")
            }

            SectionContainer {
                contentSpacing: Tokens.spacing.small / 2

                Repeater {
                    model: root.mons

                    PropertyRow {
                        required property var modelData
                        required property int index

                        showTopMargin: index > 0
                        label: modelData.name + (modelData.focused ? qsTr("  (primary)") : "")
                        value: modelData.disabled ? qsTr("off") : `${modelData.width}×${modelData.height} @${Math.round(modelData.refreshRate)} · ${modelData.x},${modelData.y} · ×${modelData.scale}`
                    }
                }
            }

            SectionContainer {
                SplitButtonRow {
                    label: qsTr("Arrangement")
                    active: root.arrangeMode === "mirror" ? mirrorItem : (root.arrangeMode === "single" ? singleItem : extendItem)
                    menuItems: [
                        MenuItem {
                            id: extendItem

                            text: qsTr("Extend")
                            icon: "open_in_full"
                            onClicked: root.arrangeMode = "extend"
                        },
                        MenuItem {
                            id: mirrorItem

                            text: qsTr("Mirror")
                            icon: "join_inner"
                            onClicked: root.arrangeMode = "mirror"
                        },
                        MenuItem {
                            id: singleItem

                            text: qsTr("Single (primary only)")
                            icon: "stay_primary_landscape"
                            onClicked: root.arrangeMode = "single"
                        }
                    ]
                }

                SplitButtonRow {
                    visible: root.arrangeMode === "extend" && root.mons.length >= 2
                    label: qsTr("Second screen is")
                    active: root.secondPos === "right" ? rightItem : (root.secondPos === "left" ? leftItem : (root.secondPos === "above" ? aboveItem : belowItem))
                    menuItems: [
                        MenuItem {
                            id: leftItem

                            text: qsTr("Left")
                            icon: "chevron_left"
                            onClicked: root.secondPos = "left"
                        },
                        MenuItem {
                            id: rightItem

                            text: qsTr("Right")
                            icon: "chevron_right"
                            onClicked: root.secondPos = "right"
                        },
                        MenuItem {
                            id: aboveItem

                            text: qsTr("Above")
                            icon: "keyboard_arrow_up"
                            onClicked: root.secondPos = "above"
                        },
                        MenuItem {
                            id: belowItem

                            text: qsTr("Below")
                            icon: "keyboard_arrow_down"
                            onClicked: root.secondPos = "below"
                        }
                    ]
                }
            }

            RowLayout {
                Layout.topMargin: Tokens.spacing.small
                spacing: Tokens.spacing.normal

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                    text: qsTr("Primary = the focused screen. Applies to ~/.config/hypr/monitors.conf and reloads Hyprland (old config saved as monitors.conf.bak). Resolution/scale per-monitor editing is coming next.")
                }

                StyledRect {
                    implicitWidth: applyText.implicitWidth + Tokens.padding.large * 2
                    implicitHeight: applyText.implicitHeight + Tokens.padding.normal * 2
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3primary

                    StateLayer {
                        radius: parent.radius
                        color: Colours.palette.m3onPrimary
                        onClicked: Displays.applyLines(root.buildLines())
                    }

                    StyledText {
                        id: applyText

                        anchors.centerIn: parent
                        text: qsTr("Apply")
                        color: Colours.palette.m3onPrimary
                        font.weight: 500
                    }
                }
            }

            // ── Workspaces ────────────────────────────────────────────────
            SectionHeader {
                Layout.topMargin: Tokens.spacing.large
                title: qsTr("Workspaces")
                description: qsTr("How workspaces behave across monitors")
            }

            SectionContainer {
                SplitButtonRow {
                    label: qsTr("Mode")
                    active: WorkspacePrefs.mode === "separate" ? separateItem : sharedItem
                    menuItems: [
                        MenuItem {
                            id: separateItem

                            text: qsTr("Separate per monitor")
                            icon: "splitscreen"
                            onClicked: WorkspacePrefs.setMode("separate")
                        },
                        MenuItem {
                            id: sharedItem

                            text: qsTr("Shared")
                            icon: "join_full"
                            onClicked: WorkspacePrefs.setMode("shared")
                        }
                    ]
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                wrapMode: Text.Wrap
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                text: qsTr("Separate: each monitor keeps its own workspaces and Super+1..0 follows the focused monitor. Shared: workspaces float across monitors (Hyprland default).")
            }
        }
    }
}

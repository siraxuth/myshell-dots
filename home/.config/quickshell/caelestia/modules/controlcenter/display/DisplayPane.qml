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

    // name -> {x, y} in REAL pixels (effective, i.e. divided by scale). Edited by dragging.
    property var pos: ({})
    property int rev: 0 // bump to re-evaluate the canvas layout
    property real factor: 0.1 // real px -> canvas px
    property real originX: 0
    property real originY: 0
    readonly property int snapPx: 80 // snap distance in REAL px

    // name -> { mode: "WxH@R", scale: n } chosen resolution/scale (defaults to current)
    property var chosen: ({})

    function res(m: var): string {
        return `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}`;
    }
    function cMode(m: var): string {
        return (chosen[m.name] && chosen[m.name].mode) ? chosen[m.name].mode : res(m);
    }
    function cScale(m: var): real {
        return (chosen[m.name] && chosen[m.name].scale) ? chosen[m.name].scale : m.scale;
    }
    function setChosen(name: string, key: string, val: var): void {
        const c = Object.assign({}, chosen);
        c[name] = Object.assign({}, c[name] || {});
        c[name][key] = val;
        chosen = c;
    }
    function effW(m: var): int {
        return Math.round(m.width / m.scale);
    }
    function effH(m: var): int {
        return Math.round(m.height / m.scale);
    }

    function initLayout(): void {
        const p = {};
        const c = {};
        for (const m of mons) {
            p[m.name] = {
                x: m.x,
                y: m.y
            };
            c[m.name] = {
                mode: res(m),
                scale: m.scale
            };
        }
        pos = p;
        chosen = c;
        recomputeFit();
        rev++;
    }

    function recomputeFit(): void {
        if (mons.length === 0)
            return;
        let minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
        for (const m of mons) {
            const p = pos[m.name] ?? {
                x: m.x,
                y: m.y
            };
            minX = Math.min(minX, p.x);
            minY = Math.min(minY, p.y);
            maxX = Math.max(maxX, p.x + effW(m));
            maxY = Math.max(maxY, p.y + effH(m));
        }
        const spanX = Math.max(1, maxX - minX);
        const spanY = Math.max(1, maxY - minY);
        const pad = 28;
        factor = Math.min((canvas.width - pad * 2) / spanX, (canvas.height - pad * 2) / spanY);
        // centre the bounding box in the canvas
        originX = minX - (canvas.width / factor - spanX) / 2;
        originY = minY - (canvas.height / factor - spanY) / 2;
    }

    // snap dragged monitor's edges to siblings' edges (abut + align), in REAL px
    function snap(name: string, x: real, y: real): var {
        const me = mons.find(m => m.name === name);
        if (!me)
            return {
                x,
                y
            };
        const w = effW(me), h = effH(me);
        let nx = x, ny = y;
        for (const m of mons) {
            if (m.name === name)
                continue;
            const o = root.pos[m.name];
            if (!o)
                continue;
            const ow = effW(m), oh = effH(m);
            // horizontal abut
            if (Math.abs((x + w) - o.x) < snapPx)
                nx = o.x - w;        // my right -> their left
            else if (Math.abs(x - (o.x + ow)) < snapPx)
                nx = o.x + ow;       // my left -> their right
            else if (Math.abs(x - o.x) < snapPx)
                nx = o.x;            // align left edges
            // vertical abut
            if (Math.abs((y + h) - o.y) < snapPx)
                ny = o.y - h;        // my bottom -> their top
            else if (Math.abs(y - (o.y + oh)) < snapPx)
                ny = o.y + oh;       // my top -> their bottom
            else if (Math.abs(y - o.y) < snapPx)
                ny = o.y;            // align top edges
        }
        return {
            x: Math.round(nx),
            y: Math.round(ny)
        };
    }

    function buildLines(): var {
        if (!primary)
            return [];
        const others = mons.filter(m => m.name !== primary.name);
        const lines = [];
        if (arrangeMode === "single") {
            lines.push(`monitor=${primary.name},${cMode(primary)},0x0,${cScale(primary)}`);
            for (const m of others)
                lines.push(`monitor=${m.name},disable`);
        } else if (arrangeMode === "mirror") {
            lines.push(`monitor=${primary.name},${cMode(primary)},0x0,${cScale(primary)}`);
            for (const m of others)
                lines.push(`monitor=${m.name},${cMode(m)},0x0,${cScale(m)},mirror,${primary.name}`);
        } else {
            // normalise dragged positions so the top-left is 0,0
            let minX = 1e9, minY = 1e9;
            for (const m of mons) {
                const p = pos[m.name] ?? {
                    x: m.x,
                    y: m.y
                };
                minX = Math.min(minX, p.x);
                minY = Math.min(minY, p.y);
            }
            for (const m of mons) {
                const p = pos[m.name] ?? {
                    x: m.x,
                    y: m.y
                };
                lines.push(`monitor=${m.name},${cMode(m)},${Math.round(p.x - minX)}x${Math.round(p.y - minY)},${cScale(m)}`);
            }
        }
        return lines;
    }

    Component.onCompleted: Qt.callLater(initLayout)

    Connections {
        target: Displays
        function onMonitorsChanged(): void {
            root.initLayout();
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

            SectionHeader {
                Layout.topMargin: Tokens.spacing.large
                title: qsTr("Monitors")
                description: qsTr("Drag the screens to arrange them — applied to monitors.conf")
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
            }

            // ── Drag canvas (Extend only) ─────────────────────────────────
            StyledRect {
                id: canvas

                visible: root.arrangeMode === "extend"
                Layout.fillWidth: true
                implicitHeight: 260
                radius: Tokens.rounding.normal
                color: Colours.palette.m3surfaceContainerHigh

                onWidthChanged: root.recomputeFit()

                Repeater {
                    model: root.mons

                    StyledRect {
                        id: screen

                        required property var modelData

                        // x/y are positioned imperatively (drag.target writes them, which would
                        // break a declarative binding), so reposition via place() on rev/factor.
                        function place(): void {
                            const p = root.pos[modelData.name] ?? {
                                x: modelData.x,
                                y: modelData.y
                            };
                            x = 28 + (p.x - root.originX) * root.factor;
                            y = 28 + (p.y - root.originY) * root.factor;
                        }

                        width: Math.max(24, root.effW(modelData) * root.factor)
                        height: Math.max(18, root.effH(modelData) * root.factor)

                        radius: Tokens.rounding.small
                        color: modelData.focused ? Colours.palette.m3primaryContainer : Colours.palette.m3secondaryContainer
                        border.width: dragArea.drag.active ? 2 : 1
                        border.color: modelData.focused ? Colours.palette.m3primary : Colours.palette.m3outline
                        z: dragArea.drag.active ? 10 : 1

                        Component.onCompleted: place()

                        Connections {
                            target: root
                            function onRevChanged(): void {
                                if (!dragArea.drag.active)
                                    screen.place();
                            }
                            function onFactorChanged(): void {
                                if (!dragArea.drag.active)
                                    screen.place();
                            }
                        }

                        StyledText {
                            anchors.centerIn: parent
                            width: parent.width - Tokens.padding.small * 2
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            color: modelData.focused ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSecondaryContainer
                            font.pointSize: Tokens.font.size.small
                            text: screen.modelData.name + (screen.modelData.focused ? "★" : "") + "\n" + screen.modelData.width + "×" + screen.modelData.height
                        }

                        MouseArea {
                            id: dragArea

                            anchors.fill: parent
                            cursorShape: Qt.OpenHandCursor
                            drag.target: parent
                            drag.threshold: 0

                            onReleased: {
                                const rx = (screen.x - 28) / root.factor + root.originX;
                                const ry = (screen.y - 28) / root.factor + root.originY;
                                const snapped = root.snap(screen.modelData.name, rx, ry);
                                const np = Object.assign({}, root.pos);
                                np[screen.modelData.name] = snapped;
                                root.pos = np;
                                root.rev++;
                                screen.place();
                            }
                        }
                    }
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
                    text: qsTr("Drag screens to position them (they snap to each other's edges). ★ = primary (focused). Apply writes ~/.config/hypr/monitors.conf (backup: monitors.conf.bak) and reloads.")
                }

                StyledRect {
                    implicitWidth: resetText.implicitWidth + Tokens.padding.large * 2
                    implicitHeight: resetText.implicitHeight + Tokens.padding.normal * 2
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3surfaceContainerHighest

                    StateLayer {
                        radius: parent.radius
                        onClicked: root.initLayout()
                    }

                    StyledText {
                        id: resetText

                        anchors.centerIn: parent
                        text: qsTr("Reset")
                        color: Colours.palette.m3onSurface
                    }
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

            // ── Resolution & scale ────────────────────────────────────────
            SectionHeader {
                Layout.topMargin: Tokens.spacing.large
                title: qsTr("Resolution & scale")
                description: qsTr("Every mode the monitor reports — applied on Apply")
            }

            Repeater {
                model: root.mons

                ModeSelector {
                    required property var modelData

                    Layout.fillWidth: true
                    monitor: modelData
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

    // Per-monitor resolution + scale picker (lists every mode the monitor reports).
    component ModeSelector: ColumnLayout {
        id: sel

        property var monitor
        property bool open: false

        spacing: Tokens.spacing.small / 2

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: hdr.implicitHeight + Tokens.padding.large * 2
            radius: Tokens.rounding.normal
            color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

            StateLayer {
                radius: parent.radius
                onClicked: sel.open = !sel.open
            }

            RowLayout {
                id: hdr

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.normal

                StyledText {
                    Layout.fillWidth: true
                    text: sel.monitor.name + (sel.monitor.focused ? " ★" : "")
                    color: Colours.palette.m3onSurface
                }

                StyledText {
                    text: root.cMode(sel.monitor) + "  ·  ×" + root.cScale(sel.monitor)
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                }

                MaterialIcon {
                    text: sel.open ? "expand_less" : "expand_more"
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            active: sel.open
            visible: active

            sourceComponent: ColumnLayout {
                width: sel.width
                spacing: Tokens.spacing.small / 2

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Tokens.padding.normal
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("Scale")
                        color: Colours.palette.m3onSurfaceVariant
                        Layout.rightMargin: Tokens.spacing.normal
                    }

                    Repeater {
                        model: [1.0, 1.25, 1.5, 2.0]

                        StyledRect {
                            required property var modelData

                            readonly property bool picked: Math.abs(root.cScale(sel.monitor) - modelData) < 0.01

                            implicitWidth: st.implicitWidth + Tokens.padding.normal * 2
                            implicitHeight: st.implicitHeight + Tokens.padding.small * 2
                            radius: Tokens.rounding.full
                            color: picked ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainer, 2)

                            StateLayer {
                                radius: parent.radius
                                onClicked: root.setChosen(sel.monitor.name, "scale", modelData)
                            }

                            StyledText {
                                id: st

                                anchors.centerIn: parent
                                text: "×" + modelData
                                color: parent.picked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                font.pointSize: Tokens.font.size.small
                            }
                        }
                    }
                }

                Repeater {
                    model: sel.monitor.availableModes

                    StyledRect {
                        required property var modelData

                        readonly property string m: ("" + modelData).replace("Hz", "")
                        readonly property bool picked: root.cMode(sel.monitor) === m

                        Layout.fillWidth: true
                        implicitHeight: mt.implicitHeight + Tokens.padding.normal * 2
                        radius: Tokens.rounding.small
                        color: picked ? Colours.palette.m3primaryContainer : "transparent"

                        StateLayer {
                            radius: parent.radius
                            onClicked: root.setChosen(sel.monitor.name, "mode", parent.m)
                        }

                        StyledText {
                            id: mt

                            anchors.left: parent.left
                            anchors.leftMargin: Tokens.padding.normal
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData
                            color: parent.picked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                        }
                    }
                }
            }
        }
    }
}

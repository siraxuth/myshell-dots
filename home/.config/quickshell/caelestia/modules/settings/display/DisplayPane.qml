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
    function modeResolution(mode: string): string {
        const match = mode.match(/^(\d+x\d+)@([\d.]+)(?:Hz)?$/);
        return match ? match[1] : "";
    }
    function modeRate(mode: string): real {
        const match = mode.match(/@(\d+(?:\.\d+)?)(?:Hz)?$/);
        return match ? Number(match[1]) : 0;
    }
    function cleanMode(mode: var): string {
        return ("" + mode).replace(/Hz$/, "");
    }
    function modesForResolution(m: var, resolution: string): var {
        return (m.availableModes ?? []).map(cleanMode)
            .filter(mode => modeResolution(mode) === resolution)
            .sort((a, b) => modeRate(b) - modeRate(a));
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

    PaneFrame {
        anchors.fill: parent

        Flickable {
            id: settingsScroller1
            SettingsScrollHandler {
                flickable: settingsScroller1
            }

            anchors.fill: parent
            contentHeight: layout.implicitHeight
            clip: true

            ColumnLayout {
                id: layout

                width: parent.width
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
                title: qsTr("Resolution, refresh rate & scale")
                description: qsTr("Choose a resolution first, then pick a refresh rate supported by that display")
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
        readonly property var resolutions: [...new Set((monitor.availableModes ?? []).map(mode => root.modeResolution(root.cleanMode(mode))).filter(Boolean))]
            .sort((a, b) => {
                const [aw, ah] = a.split("x").map(Number);
                const [bw, bh] = b.split("x").map(Number);
                return (bw * bh) - (aw * ah) || bw - aw;
            })
        readonly property string selectedResolution: root.modeResolution(root.cMode(monitor)) || `${monitor.width}x${monitor.height}`
        readonly property var selectedModes: root.modesForResolution(monitor, selectedResolution)

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

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("1 · Resolution")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.small
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: sel.resolutions

                            StyledRect {
                                required property string modelData
                                readonly property bool picked: sel.selectedResolution === modelData
                                implicitWidth: resolutionText.implicitWidth + Tokens.padding.large * 2
                                implicitHeight: resolutionText.implicitHeight + Tokens.padding.normal * 2
                                radius: Tokens.rounding.full
                                color: picked ? Colours.palette.m3primaryContainer : Colours.layer(Colours.palette.m3surfaceContainer, 2)
                                border.width: picked ? 1 : 0
                                border.color: Colours.palette.m3primary

                                StateLayer {
                                    radius: parent.radius
                                    onClicked: {
                                        const modes = root.modesForResolution(sel.monitor, parent.modelData);
                                        if (!modes.length)
                                            return;
                                        // A resolution change starts at the best refresh rate the panel supports.
                                        root.setChosen(sel.monitor.name, "mode", modes[0]);
                                    }
                                }

                                StyledText {
                                    id: resolutionText
                                    anchors.centerIn: parent
                                    text: modelData.replace("x", " × ")
                                    color: parent.picked ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                    font.weight: parent.picked ? 600 : 400
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("2 · Refresh rate")
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Tokens.font.size.small
                        }
                        StyledText {
                            text: sel.selectedModes.length ? qsTr("%1 options").arg(sel.selectedModes.length) : qsTr("No modes reported")
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Tokens.font.size.small
                        }
                        StyledRect {
                            visible: sel.selectedModes.length > 0
                            implicitWidth: autoText.implicitWidth + Tokens.padding.large * 2
                            implicitHeight: autoText.implicitHeight + Tokens.padding.small * 2
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3secondaryContainer

                            StateLayer {
                                radius: parent.radius
                                onClicked: root.setChosen(sel.monitor.name, "mode", sel.selectedModes[0])
                            }

                            StyledText {
                                id: autoText
                                anchors.centerIn: parent
                                text: qsTr("Auto · %1 Hz").arg(root.modeRate(sel.selectedModes[0] ?? ""))
                                color: Colours.palette.m3onSecondaryContainer
                                font.pointSize: Tokens.font.size.small
                                font.weight: 600
                            }
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: sel.selectedModes

                            StyledRect {
                                required property string modelData
                                readonly property bool picked: root.cMode(sel.monitor) === modelData
                                implicitWidth: rateText.implicitWidth + Tokens.padding.large * 2
                                implicitHeight: rateText.implicitHeight + Tokens.padding.normal * 2
                                radius: Tokens.rounding.full
                                color: picked ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainer, 2)
                                border.width: picked ? 1 : 0
                                border.color: Colours.palette.m3primary

                                StateLayer {
                                    radius: parent.radius
                                    onClicked: root.setChosen(sel.monitor.name, "mode", parent.modelData)
                                }

                                StyledText {
                                    id: rateText
                                    anchors.centerIn: parent
                                    text: `${root.modeRate(modelData)} Hz` + (index === 0 ? `  ·  ${qsTr("Fastest")}` : "")
                                    color: parent.picked ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                    font.weight: parent.picked ? 600 : 400
                                }
                            }
                        }
                    }

                }
            }
            }
        }
    }
}

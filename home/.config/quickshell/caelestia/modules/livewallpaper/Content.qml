pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property DrawerVisibilities visibilities

    readonly property var entries: Wallpapers.allEntries
    readonly property int itemCount: entries.length
    property int selIndex: 0
    property bool navigated: false

    readonly property real nonAnimHeight: layout.implicitHeight + Tokens.padding.larger * 2

    implicitWidth: 960
    implicitHeight: nonAnimHeight

    focus: true
    onActiveFocusChanged: {
        if (!activeFocus && visibilities.liveWallpaper)
            Qt.callLater(() => {
                if (visibilities.liveWallpaper)
                    forceActiveFocus();
            });
    }

    function selPath(i: int): string {
        return (i >= 0 && i < entries.length) ? entries[i].path : "";
    }

    function syncToCurrent(): void {
        const c = Wallpapers.actualCurrent;
        if (!c) { selIndex = 0; return; }
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].path === c) { selIndex = i; return; }
        }
        selIndex = 0;
    }

    function move(delta: int): void {
        navigated = true;
        selIndex = Math.max(0, Math.min(itemCount - 1, selIndex + delta));
        previewTimer.restart();
        updateScroll();
    }

    function updateScroll(): void {
        const tileW = 200;
        const step = tileW + Tokens.spacing.normal;
        const target = selIndex * step - (strip.width - tileW) / 2;
        strip.contentX = Math.max(0, Math.min(target, Math.max(0, strip.contentWidth - strip.width)));
    }

    Component.onCompleted: {
        navigated = false;
        syncToCurrent();
        Qt.callLater(() => {
            updateScroll();
            forceActiveFocus();
        });
    }

    Connections {
        target: root.visibilities

        function onLiveWallpaperChanged(): void {
            if (!root.visibilities.liveWallpaper) return;
            root.navigated = false;
            root.syncToCurrent();
            Qt.callLater(() => {
                root.updateScroll();
                root.forceActiveFocus();
            });
        }
    }

    Connections {
        target: Wallpapers

        function onAllEntriesChanged(): void {
            if (root.visibilities.liveWallpaper && !root.navigated)
                root.syncToCurrent();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            Wallpapers.stopPreview();
            root.visibilities.liveWallpaper = false;
            event.accepted = true;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            root.move(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            root.move(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const path = root.selPath(root.selIndex);
            if (path) {
                if (Colours.scheme === "dynamic" && path !== Wallpapers.actualCurrent)
                    Wallpapers.previewColourLock = true;
                Wallpapers.setWallpaper(path);
            }
            root.visibilities.liveWallpaper = false;
            event.accepted = true;
        } else if (event.key === Qt.Key_Tab) {
            root.selectRandom();
            event.accepted = true;
        } else if (event.key === Qt.Key_Backtab) {
            Wallpapers.cycleColorFilter(false);
            event.accepted = true;
        }
    }

    function selectRandom(): void {
        if (entries.length <= 1) return;
        let idx = selIndex;
        while (idx === selIndex) idx = Math.floor(Math.random() * entries.length);
        selIndex = idx;
        navigated = true;
        previewTimer.restart();
        updateScroll();
    }

    Timer {
        id: previewTimer

        interval: 300
        onTriggered: {
            const path = root.selPath(root.selIndex);
            if (path) Wallpapers.preview(path);
            else Wallpapers.stopPreview();
            Qt.callLater(() => root.forceActiveFocus());
        }
    }

    Timer {
        running: root.visibilities.liveWallpaper
        interval: 150
        repeat: true
        onTriggered: if (!root.activeFocus) root.forceActiveFocus()
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.larger
        spacing: Tokens.spacing.normal

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.normal

            MaterialIcon {
                text: "wallpaper"
                color: Colours.palette.m3primary
                font.pointSize: Tokens.font.size.large
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Wallpaper")
                font.pointSize: Tokens.font.size.large
                font.bold: true
                color: Colours.palette.m3onSurface
            }

            IconTextButton {
                icon: "collections"
                text: qsTr("All")
                toggle: true
                checked: Wallpapers.filterMode === 2
                onClicked: Wallpapers.filterMode = 2
            }
            IconTextButton {
                icon: "image"
                text: qsTr("Static")
                toggle: true
                checked: Wallpapers.filterMode === 0
                onClicked: Wallpapers.filterMode = 0
            }
            IconTextButton {
                icon: "smart_display"
                text: qsTr("Live")
                toggle: true
                checked: Wallpapers.filterMode === 1
                onClicked: Wallpapers.filterMode = 1
            }
            IconTextButton {
                icon: "shuffle"
                text: qsTr("Random")
                onClicked: root.selectRandom()
            }

            StyledText {
                text: qsTr("← → Tab Esc")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
            }
        }

        // Color filter bar
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.small

            // Active badge
            StyledRect {
                anchors.verticalCenter: parent.verticalCenter
                color: Wallpapers.colorFilter !== "" ? Colours.palette.m3secondaryContainer : "transparent"
                radius: Tokens.rounding.small
                implicitWidth: badgeRow.implicitWidth + (Wallpapers.colorFilter !== "" ? Tokens.padding.normal : Tokens.padding.small)
                implicitHeight: 26

                Row {
                    id: badgeRow
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.smaller

                    MaterialIcon {
                        text: "palette"
                        font.pointSize: Tokens.font.size.small
                        color: Wallpapers.colorFilter !== "" ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: {
                            if (!Wallpapers.colorFilter || Wallpapers.colorFilter === "") return qsTr("All");
                            const map = {"red": qsTr("Red"), "orange": qsTr("Orange"), "yellow": qsTr("Yellow"), "green": qsTr("Green"), "blue": qsTr("Blue"), "purple": qsTr("Purple"), "pink": qsTr("Pink"), "white": qsTr("White"), "black": qsTr("Black")};
                            return map[Wallpapers.colorFilter] || Wallpapers.colorFilter;
                        }
                        font.pointSize: Tokens.font.size.small
                        color: Wallpapers.colorFilter !== "" ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MaterialIcon {
                        visible: Wallpapers.colorFilter !== ""
                        text: "close"
                        font.pointSize: Tokens.font.size.small
                        color: Colours.palette.m3onSecondaryContainer
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                StateLayer {
                    radius: parent.radius
                    disabled: Wallpapers.colorFilter === ""
                    onClicked: Wallpapers.colorFilter = ""
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: 18
                color: Colours.palette.m3outlineVariant
            }

            // Color pills
            Repeater {
                model: [
                    { id: "red", hex: "#E53935" },
                    { id: "orange", hex: "#FB8C00" },
                    { id: "yellow", hex: "#FDD835" },
                    { id: "green", hex: "#4CAF50" },
                    { id: "blue", hex: "#2196F3" },
                    { id: "purple", hex: "#9C27B0" },
                    { id: "pink", hex: "#EC407A" },
                    { id: "white", hex: "#FFFFFF" },
                    { id: "black", hex: "#1A1A1A" }
                ]

                delegate: Item {
                    id: pillDel
                    required property var modelData
                    readonly property bool isSelected: Wallpapers.colorFilter === modelData.id

                    anchors.verticalCenter: parent.verticalCenter
                    width: isSelected ? 28 : 20
                    height: 20

                    Behavior on width { Anim { duration: 150 } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width; height: parent.height
                        radius: Tokens.rounding.extraSmall
                        color: pillDel.modelData.hex
                        border.width: pillDel.isSelected ? 2 : (pillDel.modelData.id === "black" || pillDel.modelData.id === "white" ? 1 : 0)
                        border.color: pillDel.isSelected ? Colours.palette.m3onSurface : Colours.palette.m3outlineVariant

                        StateLayer {
                            radius: parent.radius
                            onClicked: {
                                if (Wallpapers.colorFilter === pillDel.modelData.id)
                                    Wallpapers.colorFilter = "";
                                else
                                    Wallpapers.colorFilter = pillDel.modelData.id;
                            }
                        }
                    }
                }
            }
        }

        // Empty state
        StyledText {
            visible: root.entries.length === 0
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("No wallpapers found for this filter.")
            color: Colours.palette.m3onSurfaceVariant
        }

        // Tile strip
        Flickable {
            id: strip

            visible: root.entries.length > 0
            Layout.fillWidth: true
            implicitHeight: 180
            contentWidth: tiles.implicitWidth
            contentHeight: height
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Behavior on contentX { Anim {} }

            Row {
                id: tiles

                spacing: Tokens.spacing.normal

                Repeater {
                    model: root.entries

                    Tile {
                        required property int index
                        required property var modelData

                        wallpaperPath: modelData.path
                        active: root.selIndex === index
                        onClicked: {
                            root.selIndex = index;
                            const path = modelData.path;
                            if (Colours.scheme === "dynamic" && path !== Wallpapers.actualCurrent)
                                Wallpapers.previewColourLock = true;
                            Wallpapers.setWallpaper(path);
                            root.visibilities.liveWallpaper = false;
                        }
                    }
                }
            }
        }
    }

    component Tile: Item {
        id: tile

        property string wallpaperPath
        property bool active
        signal clicked

        readonly property bool isVideo: Wallpapers.isVideoPath(wallpaperPath)
        readonly property string thumbPath: {
            if (!wallpaperPath) return "";
            let cached = Wallpapers.thumbPath(wallpaperPath);
            return cached || wallpaperPath;
        }

        readonly property string formatIcon: isVideo ? "smart_display" : "image"
        readonly property string formatText: {
            let props = Wallpapers.propertiesCache[wallpaperPath];
            if (props) {
                let str = typeof props === "string" ? props : (props.info || "");
                let parts = str.split(", ");
                if (parts.length >= 2) return parts[1].trim();
            }
            return wallpaperPath.split(".").pop().toUpperCase();
        }
        readonly property string fpsText: {
            let props = Wallpapers.propertiesCache[wallpaperPath];
            if (props) {
                let str = typeof props === "string" ? props : (props.info || "");
                let parts = str.split(", ");
                if (parts.length === 3) return parts[2].trim();
            }
            return "";
        }
        readonly property string resText: {
            let props = Wallpapers.propertiesCache[wallpaperPath];
            if (props) {
                let str = typeof props === "string" ? props : (props.info || "");
                let parts = str.split(", ");
                return parts[0].trim();
            }
            let fileName = wallpaperPath.split("/").pop();
            return fileName.substring(0, fileName.lastIndexOf(".")) || fileName;
        }

        implicitWidth: 200
        implicitHeight: thumb.implicitHeight + lbl.implicitHeight + Tokens.spacing.small

        StyledClippingRect {
            id: thumb

            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: tile.width
            implicitHeight: Math.round(implicitWidth / 16 * 9)
            radius: Tokens.rounding.normal
            color: tile.active ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
            border.width: tile.active ? 3 : 0
            border.color: Colours.palette.m3primary

            MaterialIcon {
                anchors.centerIn: parent
                text: tile.formatIcon
                color: tile.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.extraLarge * 2
                visible: !preview.visible
            }

            Image {
                id: preview

                anchors.fill: parent
                visible: status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                source: tile.thumbPath ? "file://" + tile.thumbPath : ""
            }

            // Format badge (top-left)
            StyledRect {
                z: 2
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: Tokens.spacing.smaller
                visible: tile.formatText !== ""
                color: Qt.rgba(Colours.palette.m3surfaceContainer.r, Colours.palette.m3surfaceContainer.g, Colours.palette.m3surfaceContainer.b, 0.85)
                radius: Tokens.rounding.extraSmall
                implicitWidth: fmtRow.implicitWidth + Tokens.padding.smaller * 2
                implicitHeight: fmtRow.implicitHeight + 2

                Row {
                    id: fmtRow
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.smaller

                    MaterialIcon {
                        text: tile.formatIcon
                        font.pointSize: Tokens.font.size.smaller
                        color: Colours.palette.m3onSurface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: tile.formatText
                        font.pointSize: Tokens.font.size.smaller
                        color: Colours.palette.m3onSurface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // FPS badge (top-right, videos only)
            StyledRect {
                z: 2
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: Tokens.spacing.smaller
                visible: tile.fpsText !== ""
                color: Qt.rgba(Colours.palette.m3surfaceContainer.r, Colours.palette.m3surfaceContainer.g, Colours.palette.m3surfaceContainer.b, 0.85)
                radius: Tokens.rounding.extraSmall
                implicitWidth: fpsRow.implicitWidth + Tokens.padding.smaller * 2
                implicitHeight: fpsRow.implicitHeight + 2

                Row {
                    id: fpsRow
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.smaller

                    MaterialIcon {
                        text: "speed"
                        font.pointSize: Tokens.font.size.smaller
                        color: Colours.palette.m3onSurface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    StyledText {
                        text: tile.fpsText
                        font.pointSize: Tokens.font.size.smaller
                        color: Colours.palette.m3onSurface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            StateLayer {
                radius: thumb.radius
                onClicked: tile.clicked()
            }
        }

        StyledText {
            id: lbl

            anchors.top: thumb.bottom
            anchors.topMargin: Tokens.spacing.small
            anchors.horizontalCenter: parent.horizontalCenter

            width: thumb.width - Tokens.padding.normal * 2
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            maximumLineCount: 1
            text: tile.resText
            font.pointSize: Tokens.font.size.small
            color: tile.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        }
    }
}

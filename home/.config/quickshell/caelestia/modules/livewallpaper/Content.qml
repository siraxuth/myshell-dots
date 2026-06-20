pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property DrawerVisibilities visibilities

    readonly property int itemCount: LiveWallpaper.videos.length + 1 // index 0 = None/Stop
    property int selIndex: 0
    property bool navigated: false // true once the user moves with arrows/click

    readonly property real nonAnimHeight: layout.implicitHeight + Tokens.padding.larger * 2

    implicitWidth: 880
    implicitHeight: nonAnimHeight

    focus: true
    // Re-grab keyboard if anything steals it while the picker is open (e.g. a tile rebuild),
    // so the arrow keys keep working. Nothing inside the picker needs text focus.
    onActiveFocusChanged: {
        if (!activeFocus && visibilities.liveWallpaper)
            Qt.callLater(() => {
                if (visibilities.liveWallpaper)
                    forceActiveFocus();
            });
    }

    function selPath(i: int): string {
        return i <= 0 ? "" : LiveWallpaper.videos[i - 1];
    }

    // Highlight whatever is currently playing (index 0 = None/Stop).
    function syncToCurrent(): void {
        const c = LiveWallpaper.current;
        const idx = c ? LiveWallpaper.videos.indexOf(c) + 1 : 0;
        selIndex = idx < 0 ? 0 : idx;
    }

    function move(delta: int): void {
        navigated = true;
        selIndex = Math.max(0, Math.min(itemCount - 1, selIndex + delta));
        previewTimer.restart();
        updateScroll();
    }

    function updateScroll(): void {
        const tileW = 220;
        const step = tileW + Tokens.spacing.normal;
        const target = selIndex * step - (strip.width - tileW) / 2;
        strip.contentX = Math.max(0, Math.min(target, Math.max(0, strip.contentWidth - strip.width)));
    }

    // The Content is created the moment the picker opens (Loader activates), so init here —
    // a Connections on visibilities would miss the very transition that creates this item.
    Component.onCompleted: {
        LiveWallpaper.snapshot();
        LiveWallpaper.refresh();
        navigated = false;
        syncToCurrent();
        Qt.callLater(() => {
            updateScroll();
            forceActiveFocus();
        });
    }

    // Handles re-open while the close animation is still running (Content not yet destroyed).
    Connections {
        target: root.visibilities

        function onLiveWallpaperChanged(): void {
            if (!root.visibilities.liveWallpaper)
                return;
            LiveWallpaper.snapshot();
            LiveWallpaper.refresh();
            root.navigated = false;
            root.syncToCurrent();
            Qt.callLater(() => {
                root.updateScroll();
                root.forceActiveFocus();
            });
        }
    }

    // `find` is async — re-sync the highlight once the list arrives, unless the user moved.
    Connections {
        target: LiveWallpaper

        function onVideosChanged(): void {
            if (root.visibilities.liveWallpaper && !root.navigated)
                root.syncToCurrent();
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            // Esc just closes the picker UI — keep whatever's currently playing (don't stop/revert).
            LiveWallpaper.commit();
            root.visibilities.liveWallpaper = false;
            event.accepted = true;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            root.move(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            root.move(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            LiveWallpaper.commit();
            root.visibilities.liveWallpaper = false;
            event.accepted = true;
        }
    }

    Timer {
        id: previewTimer

        interval: 300
        onTriggered: {
            LiveWallpaper.apply(root.selPath(root.selIndex));
            // mpvpaper churning its surface can drop our keyboard focus — reclaim it right away
            // so the next arrow press keeps working without needing a mouse hover.
            Qt.callLater(() => root.forceActiveFocus());
        }
    }

    // Keep keyboard focus while open. Thumbnail/Image loads and other scene churn can quietly
    // steal it; this re-grabs so the arrow keys never stop working mid-session.
    Timer {
        running: root.visibilities.liveWallpaper
        interval: 150
        repeat: true
        onTriggered: if (!root.activeFocus)
            root.forceActiveFocus()
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.larger
        spacing: Tokens.spacing.normal

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.normal

            MaterialIcon {
                text: "movie"
                color: Colours.palette.m3primary
                font.pointSize: Tokens.font.size.large
            }

            StyledText {
                Layout.fillWidth: true
                text: qsTr("Live Wallpaper")
                font.pointSize: Tokens.font.size.large
                font.bold: true
                color: Colours.palette.m3onSurface
            }

            StyledText {
                text: qsTr("← → select · Enter apply · Esc cancel")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
            }

            StyledText {
                Layout.leftMargin: Tokens.spacing.normal
                text: qsTr("Autostart")
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledRect {
                implicitWidth: 46
                implicitHeight: 26
                radius: Tokens.rounding.full
                color: LiveWallpaper.autostart ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest

                StateLayer {
                    radius: parent.radius
                    onClicked: LiveWallpaper.setAutostart(!LiveWallpaper.autostart)
                }

                StyledRect {
                    implicitWidth: 18
                    implicitHeight: 18
                    radius: Tokens.rounding.full
                    anchors.verticalCenter: parent.verticalCenter
                    x: LiveWallpaper.autostart ? parent.width - width - 4 : 4
                    color: LiveWallpaper.autostart ? Colours.palette.m3onPrimary : Colours.palette.m3outline

                    Behavior on x {
                        Anim {}
                    }
                }
            }
        }

        StyledText {
            visible: LiveWallpaper.videos.length === 0
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("No videos in %1\nDrop .mp4 / .webm files there, then reopen.").arg(Paths.shortenHome(LiveWallpaper.dir))
            color: Colours.palette.m3onSurfaceVariant
        }

        Flickable {
            id: strip

            visible: LiveWallpaper.videos.length > 0
            Layout.fillWidth: true
            implicitHeight: 168
            contentWidth: tiles.implicitWidth
            contentHeight: height
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            Behavior on contentX {
                Anim {}
            }

            Row {
                id: tiles

                spacing: Tokens.spacing.normal

                Tile {
                    icon: "block"
                    label: qsTr("None / Stop")
                    active: root.selIndex === 0
                    onClicked: {
                        root.selIndex = 0;
                        LiveWallpaper.apply("");
                        LiveWallpaper.commit();
                        root.visibilities.liveWallpaper = false;
                    }
                }

                Repeater {
                    model: LiveWallpaper.videos

                    Tile {
                        required property int index
                        required property string modelData

                        videoPath: modelData
                        icon: "movie"
                        label: modelData.split("/").pop()
                        active: root.selIndex === index + 1
                        onClicked: {
                            root.selIndex = index + 1;
                            LiveWallpaper.apply(modelData);
                            LiveWallpaper.commit();
                            root.visibilities.liveWallpaper = false;
                        }
                    }
                }
            }
        }
    }

    component Tile: Item {
        id: tile

        property string videoPath // "" = the None/Stop tile
        property string icon
        property string label
        property bool active
        signal clicked

        implicitWidth: 220
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
                text: tile.icon
                color: tile.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.extraLarge * 2
                visible: !preview.visible
            }

            Image {
                id: preview

                anchors.fill: parent
                visible: !!tile.videoPath && status === Image.Ready
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                source: tile.videoPath ? "file://" + LiveWallpaper.thumbPath(tile.videoPath) : ""

                Connections {
                    target: LiveWallpaper
                    function onThumbRevChanged(): void {
                        if (!tile.videoPath)
                            return;
                        preview.source = "";
                        preview.source = "file://" + LiveWallpaper.thumbPath(tile.videoPath);
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
            text: tile.label
            color: tile.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
        }
    }
}

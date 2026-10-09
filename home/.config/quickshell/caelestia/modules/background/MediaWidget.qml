pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Caelestia.Services
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    required property var widget
    property bool bgVisible: true
    property string variant: "full"
    property int lyricsLines: 1
    property string lyricsAlignment: "left"
    property bool showAlbumArt: widget.wProps?.showAlbumArt !== false
    property bool showControls: widget.wProps?.showControls !== false
    property bool showProgress: widget.wProps?.showProgress !== false
    property bool showVisualizer: widget.wProps?.showVisualizer !== false
    readonly property int lyricSideLines: variant === "simpleLyrics" ? Math.max(0, Math.min(4, lyricsLines)) : 2
    readonly property var player: {
        const identity = String(widget.wProps?.playerIdentity ?? "");
        return identity ? Players.list.find(candidate => Players.getIdentity(candidate) === identity) ?? Players.active : Players.active;
    }
    readonly property bool artBackgroundVisible: showAlbumArt && !!player && backgroundArt.status === Image.Ready
    readonly property color textColor: resolveColor(widget.wProps?.textColor, artBackgroundVisible ? "#ffffff" : Colours.palette.m3onSurface)
    readonly property color secondaryTextColor: Qt.alpha(textColor, 0.72)
    readonly property color accentColor: resolveColor(widget.wProps?.accentColor, Colours.palette.m3primary)
    readonly property int widgetAlignment: lyricsAlignment === "center" ? Text.AlignHCenter : lyricsAlignment === "right" ? Text.AlignRight : Text.AlignLeft

    ServiceRef { service: Audio.cava }

    function resolveColor(raw: var, fallback: color): color {
        const value = String(raw ?? "").trim().toLowerCase();
        if (value === "primary") return Colours.palette.m3primary;
        if (value === "secondary") return Colours.palette.m3secondary;
        if (value === "tertiary") return Colours.palette.m3tertiary;
        if (value === "primarycontainer") return Colours.palette.m3primaryContainer;
        if (/^#[0-9a-f]{6}$/i.test(value)) return Qt.color(value);
        return fallback;
    }

    visible: !!player || variant === "lyrics" || variant === "simpleLyrics"
    implicitWidth: variant === "round" ? 260 : 420
    implicitHeight: variant === "round" ? implicitWidth : layout.implicitHeight + Tokens.padding.large * 2
    radius: variant === "round" ? Math.min(width, height) / 2 : Tokens.rounding.large
    clip: variant === "round"
    color: "transparent"

    Image {
        id: backgroundArt
        anchors.fill: parent
        z: 0
        source: root.showAlbumArt && root.player ? Players.getArtUrl(root.player) : ""
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.max(1, width * 2), Math.max(1, height * 2))
        visible: root.showAlbumArt && !!root.player
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }

    Rectangle {
        anchors.fill: parent
        z: 1
        visible: root.artBackgroundVisible
        color: "#99000000"
        gradient: Gradient {
            GradientStop { position: 0; color: "#66000000" }
            GradientStop { position: 1; color: "#cc000000" }
        }
    }

    ColumnLayout {
        id: layout
        z: 2
        visible: root.variant !== "round"
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.normal

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.smaller
                    StyledRect {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 7
                        implicitHeight: 7
                        radius: Tokens.rounding.full
                        color: root.player?.isPlaying ? root.accentColor : Colours.palette.m3outline
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.player ? Players.getIdentity(root.player) : qsTr("No player connected")
                        color: root.secondaryTextColor
                        font.pointSize: Tokens.font.size.smaller
                        elide: Text.ElideRight
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.variant !== "lyrics" && root.variant !== "simpleLyrics"
                    text: root.player?.trackTitle || qsTr("Nothing playing")
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    font.pointSize: Tokens.font.size.large
                    font.bold: true
                    color: root.textColor
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: root.variant !== "lyrics" && root.variant !== "simpleLyrics"
                    text: root.player?.trackArtist ?? ""
                    elide: Text.ElideRight
                    color: root.secondaryTextColor
                    font.pointSize: Tokens.font.size.small
                }

                RowLayout {
                    Layout.topMargin: Tokens.spacing.small
                    spacing: Tokens.spacing.small
                    visible: root.showControls && root.variant !== "lyrics" && root.variant !== "simpleLyrics"

                    MediaBtn {
                        visible: root.player?.shuffleSupported ?? false
                        icon: root.player?.shuffle ? "shuffle_on" : "shuffle"
                        active: root.player?.shuffleSupported ?? false
                        toggled: root.player?.shuffle ?? false
                        accent: root.accentColor
                        onClicked: if (root.player?.shuffleSupported) root.player.shuffle = !root.player.shuffle
                    }
                    MediaBtn {
                        icon: "skip_previous"
                        active: root.player?.canGoPrevious ?? false
                        accent: root.accentColor
                        onClicked: root.player?.previous()
                    }
                    MediaBtn {
                        icon: root.player?.isPlaying ? "pause" : "play_arrow"
                        active: root.player?.canTogglePlaying ?? false
                        accent: root.accentColor
                        emphasized: true
                        implicitWidth: 40
                        implicitHeight: 40
                        onClicked: root.player?.togglePlaying()
                    }
                    MediaBtn {
                        icon: "skip_next"
                        active: root.player?.canGoNext ?? false
                        accent: root.accentColor
                        onClicked: root.player?.next()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            visible: root.showProgress && root.variant === "full" && !!root.player

            StyledText {
                text: root.formatTime(root.player?.position ?? 0)
                color: root.secondaryTextColor
                font.pointSize: Tokens.font.size.smaller
            }
            StyledSlider {
                Layout.fillWidth: true
                from: 0
                to: Math.max(1, root.player?.length ?? 0)
                value: Math.min(root.player?.position ?? 0, to)
                enabled: (root.player?.canSeek ?? false) && (root.player?.positionSupported ?? false)
                onMoved: if (root.player?.canSeek && root.player?.positionSupported) root.player.position = value
            }
            StyledText {
                text: root.formatTime(root.player?.length ?? 0)
                color: root.secondaryTextColor
                font.pointSize: Tokens.font.size.smaller
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 20
            visible: root.showVisualizer && root.variant === "full"

            Row {
                anchors.fill: parent
                spacing: 2

                Repeater {
                    id: spectrumBars
                    model: Math.min(32, Audio.cava.values.length)

                    delegate: Rectangle {
                        required property int index
                        readonly property real value: Number(Audio.cava.values[index] ?? 0)
                        width: Math.max(2, (parent.width - (spectrumBars.count - 1) * parent.spacing) / Math.max(1, spectrumBars.count))
                        height: root.player?.isPlaying ? Math.max(2, parent.height * Math.min(1, value * 1.8)) : 2
                        anchors.verticalCenter: parent.verticalCenter
                        radius: width / 2
                        color: root.accentColor
                        opacity: root.player?.isPlaying ? 0.82 : 0.28
                        Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                    }
                }
            }
        }

        StyledRect {
            Layout.fillWidth: true
            implicitHeight: 1
            visible: (root.variant === "lyrics" || root.variant === "simpleLyrics") && LyricsService.model.count > 0
            color: Qt.alpha(root.accentColor, 0.3)
        }

        StyledText {
            Layout.fillWidth: true
            visible: (root.variant === "lyrics" || root.variant === "simpleLyrics") && LyricsService.model.count === 0
            text: qsTr("No lyrics available")
            horizontalAlignment: Text.AlignHCenter
            color: root.secondaryTextColor
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.variant === "lyrics" || root.variant === "simpleLyrics"
            spacing: Tokens.spacing.small / 2

            Repeater {
                model: LyricsService.model.count > 0 ? root.lyricSideLines * 2 + 1 : 0
                StyledText {
                    id: lyricLineText
                    required property int index
                    readonly property int lyricIndex: LyricsService.currentIndex - root.lyricSideLines + index
                    Layout.fillWidth: true
                    visible: lyricIndex >= 0 && lyricIndex < LyricsService.model.count
                    text: visible ? LyricsService.model.get(lyricIndex).lyricLine : ""
                    horizontalAlignment: root.widgetAlignment
                    elide: Text.ElideRight
                    color: index === root.lyricSideLines ? root.accentColor : root.secondaryTextColor
                    opacity: index === root.lyricSideLines ? 1 : 0.68
                    font.pointSize: root.variant === "simpleLyrics" && index === root.lyricSideLines ? Tokens.font.size.large : Tokens.font.size.small
                    font.bold: index === root.lyricSideLines
                    MouseArea {
                        anchors.fill: parent
                        enabled: lyricLineText.visible
                        onClicked: {
                            const line = LyricsService.model.get(lyricLineText.lyricIndex);
                            LyricsService.jumpTo(lyricLineText.lyricIndex, line.time);
                        }
                    }
                }
            }
        }
    }

    Item {
        id: roundFace
        z: 2
        anchors.fill: parent
        visible: root.variant === "round"
        readonly property real faceRadius: Math.min(width, height) / 2

        Repeater {
            model: root.showVisualizer ? Audio.cava.values.length : 0
            Rectangle {
                required property int index
                readonly property real level: Number(Audio.cava.values[index] ?? 0)
                width: Math.max(2, roundFace.faceRadius * 0.025)
                height: Math.max(4, roundFace.faceRadius * 0.08 + level * roundFace.faceRadius * 0.22)
                x: (roundFace.width - width) / 2
                y: roundFace.height / 2 - roundFace.faceRadius * 0.78 - height
                transformOrigin: Item.Bottom
                rotation: index * 360 / Math.max(1, Audio.cava.values.length)
                radius: width / 2
                color: root.accentColor
                opacity: root.player?.isPlaying ? 1 : 0.45
                Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            }
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: parent.width * 0.72
            text: root.player?.trackTitle || qsTr("Nothing playing")
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            color: root.textColor
            font.pointSize: Tokens.font.size.small
            font.weight: 600
        }
    }

    function formatTime(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds || 0));
        return `${Math.floor(total / 60)}:${String(total % 60).padStart(2, "0")}`;
    }

    component MediaBtn: StyledRect {
        id: btn
        property string icon
        property bool active: true
        property bool emphasized: false
        property bool toggled: false
        property color accent: Colours.palette.m3primary
        signal clicked

        implicitWidth: 34
        implicitHeight: 34
        radius: Tokens.rounding.full
        color: btn.emphasized ? btn.accent : btn.toggled ? Qt.alpha(btn.accent, 0.3) : Qt.alpha(btn.accent, 0.16)
        opacity: active ? 1 : 0.4

        StateLayer {
            radius: parent.radius
            disabled: !btn.active
            color: btn.emphasized ? Colours.palette.m3onPrimary : btn.accent
            onClicked: btn.clicked()
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: btn.icon
            color: btn.emphasized ? Colours.palette.m3onPrimary : btn.accent
            font.pointSize: Tokens.font.size.normal
        }
    }
}

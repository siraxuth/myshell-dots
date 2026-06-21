pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services

StyledRect {
    id: root

    readonly property var player: Players.active
    property bool bgVisible: true

    visible: !!player
    implicitWidth: 340
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.large
    color: bgVisible ? Qt.alpha(Colours.palette.m3surface, 0.55) : "transparent"

    RowLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.normal

        StyledClippingRect {
            implicitWidth: 64
            implicitHeight: 64
            radius: Tokens.rounding.normal
            color: Colours.palette.m3surfaceContainer

            MaterialIcon {
                anchors.centerIn: parent
                text: "music_note"
                color: Colours.palette.m3onSurfaceVariant
                visible: !art.visible
            }

            CachingImage {
                id: art

                anchors.fill: parent
                path: root.player?.trackArtUrl ?? ""
                visible: !!root.player?.trackArtUrl && status === Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackTitle ?? qsTr("Nothing playing")
                elide: Text.ElideRight
                font.bold: true
                color: Colours.palette.m3onSurface
            }

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackArtist ?? ""
                elide: Text.ElideRight
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
            }

            RowLayout {
                Layout.topMargin: Tokens.spacing.small
                spacing: Tokens.spacing.small

                MediaBtn {
                    icon: "skip_previous"
                    active: root.player?.canGoPrevious ?? false
                    onClicked: root.player?.previous()
                }
                MediaBtn {
                    icon: root.player?.isPlaying ? "pause" : "play_arrow"
                    onClicked: root.player?.togglePlaying()
                }
                MediaBtn {
                    icon: "skip_next"
                    active: root.player?.canGoNext ?? false
                    onClicked: root.player?.next()
                }
            }
        }
    }

    component MediaBtn: StyledRect {
        id: btn

        property string icon
        property bool active: true
        signal clicked

        implicitWidth: 34
        implicitHeight: 34
        radius: Tokens.rounding.full
        color: Qt.alpha(Colours.palette.m3primary, 0.15)
        opacity: active ? 1 : 0.4

        StateLayer {
            radius: parent.radius
            disabled: !btn.active
            onClicked: btn.clicked()
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: btn.icon
            color: Colours.palette.m3onSurface
        }
    }
}

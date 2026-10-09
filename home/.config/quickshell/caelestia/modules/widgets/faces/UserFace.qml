pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components

Item {
    id: root

    required property var widget

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            anchors.topMargin: 0
            spacing: Tokens.spacing.small
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.normal
                StyledClippingRect {
                    Layout.preferredWidth: Math.min(parent.height, 88)
                    Layout.preferredHeight: Math.min(parent.height, 88)
                    radius: Tokens.rounding.large
                    color: Colours.palette.m3surface
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "person"
                        color: Colours.palette.m3primary
                        font.pointSize: Tokens.font.size.extraLarge * 1.5
                        visible: !avatar.visible
                    }
                    Image {
                        id: avatar
                        anchors.fill: parent
                        source: `file://${Quickshell.env("HOME")}/.face`
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        sourceSize: Qt.size(width * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1), height * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1))
                        visible: status === Image.Ready
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: root.widget.wProps?.displayName || Quickshell.env("USER") || qsTr("User")
                        color: Colours.palette.m3onSurface
                        font.pointSize: Tokens.font.size.large
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Quickshell.env("USER") || ""
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.small
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                spacing: Tokens.spacing.small
                StyledRect {
                    Layout.preferredWidth: 64
                    Layout.fillHeight: true
                    radius: Tokens.rounding.small
                    color: Colours.palette.m3secondaryContainer
                    MaterialIcon { anchors.centerIn: parent; text: "lock"; color: Colours.palette.m3onSecondaryContainer }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: Quickshell.execDetached(["loginctl", "lock-session"])
                    }
                }
                Repeater {
                    model: [
                        { icon: "bedtime", label: qsTr("Sleep"), command: "suspend", color: Colours.palette.m3secondaryContainer },
                        { icon: "restart_alt", label: qsTr("Restart"), command: "reboot", color: Colours.palette.m3tertiaryContainer },
                        { icon: "power_settings_new", label: qsTr("Power off"), command: "poweroff", color: Colours.palette.m3errorContainer }
                    ]
                    StyledRect {
                        id: actionButton
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Tokens.rounding.small
                        color: actionButton.modelData.color
                        MaterialIcon { anchors.centerIn: parent; text: actionButton.modelData.icon; color: Colours.palette.m3onSurface }
                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            text: qsTr("Hold")
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Tokens.font.size.small
                        }
                        MouseArea {
                            anchors.fill: parent
                            pressAndHoldInterval: 1200
                            onPressAndHold: Quickshell.execDetached(["systemctl", actionButton.modelData.command])
                        }
                    }
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property var widget

    readonly property var accessPoint: Network.active
    readonly property var ethernet: Network.activeEthernet
    readonly property bool connected: !!accessPoint || !!ethernet
    readonly property string connectionName: accessPoint?.ssid ?? ethernet?.name ?? ethernet?.interface ?? ""
    readonly property int strength: Math.max(0, Math.min(100, Number(accessPoint?.strength ?? 0)))

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: "transparent"
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.normal

            RowLayout {
                Layout.fillWidth: true
                MaterialIcon {
                    text: root.accessPoint ? (root.strength >= 65 ? "wifi" : root.strength > 0 ? "wifi_2_bar" : "wifi_1_bar") : root.ethernet ? "lan" : "wifi_off"
                    color: root.connected ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.extraLarge
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("NETWORK")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.smaller
                        font.weight: 700
                        font.letterSpacing: 1
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.connected ? root.connectionName : qsTr("Not connected")
                        color: Colours.palette.m3onSurface
                        font.pointSize: Tokens.font.size.large
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }
                MaterialIcon {
                    visible: root.connected
                    text: "check_circle"
                    color: Colours.palette.m3tertiary
                    font.pointSize: Tokens.font.size.large
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !!root.accessPoint
                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Wi-Fi signal")
                    color: Colours.palette.m3onSurfaceVariant
                    elide: Text.ElideRight
                }
                StyledText {
                    text: qsTr("%1%").arg(root.strength)
                    color: Colours.palette.m3onSurface
                    font.bold: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 7
                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHighest
                visible: !!root.accessPoint

                Rectangle {
                    width: parent.width * root.strength / 100
                    height: parent.height
                    radius: parent.radius
                    color: Colours.palette.m3primary
                    Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                }
            }

            StyledText {
                visible: !Network.wifiEnabled && !root.ethernet
                text: qsTr("Wi-Fi is turned off")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                elide: Text.ElideRight
            }
        }
    }
}

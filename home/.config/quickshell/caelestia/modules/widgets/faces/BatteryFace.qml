pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property var widget

    readonly property real percentage: Math.max(0, Math.min(1, Number(UPower.displayDevice.percentage ?? 0)))
    readonly property string batteryState: !UPower.displayDevice.isLaptopBattery ? qsTr("AC power connected") : UPower.onBattery ? qsTr("On battery") : qsTr("Charging")
    readonly property string remainingTime: {
        if (!UPower.displayDevice.isLaptopBattery) return "";
        const seconds = Number(UPower.onBattery ? UPower.displayDevice.timeToEmpty : UPower.displayDevice.timeToFull);
        if (!Number.isFinite(seconds) || seconds <= 0) return "";
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.round(seconds % 3600 / 60);
        return hours > 0 ? qsTr("%1 h %2 min").arg(hours).arg(minutes) : qsTr("%1 min").arg(minutes);
    }

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
                spacing: Tokens.spacing.normal
                MaterialIcon {
                    text: !UPower.displayDevice.isLaptopBattery ? "battery_unknown" : (!UPower.onBattery ? "battery_charging_full" : percentage > 0.8 ? "battery_6_bar" : percentage > 0.6 ? "battery_5_bar" : percentage > 0.4 ? "battery_3_bar" : percentage > 0.2 ? "battery_2_bar" : "battery_1_bar")
                    color: percentage < 0.15 ? Colours.palette.m3error : Colours.palette.m3primary
                    font.pointSize: Tokens.font.size.extraLarge
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: UPower.displayDevice.isLaptopBattery ? `${Math.round(root.percentage * 100)}%` : qsTr("No battery detected")
                        color: Colours.palette.m3onSurface
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.remainingTime || root.batteryState
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.small
                        elide: Text.ElideRight
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Colours.palette.m3surface
                visible: UPower.displayDevice.isLaptopBattery
                Rectangle {
                    width: parent.width * root.percentage
                    height: parent.height
                    radius: parent.radius
                    color: root.percentage < 0.15 ? Colours.palette.m3error : Colours.palette.m3primary
                    Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.misc
import qs.services

Item {
    id: root

    required property var widget
    property string metric: "cpu"

    readonly property real percentage: metric === "cpu" ? SystemUsage.cpuPerc : metric === "ram" ? SystemUsage.memPerc : metric === "disk" ? SystemUsage.storagePerc : Math.min(1, SystemUsage.cpuTemp / 100)
    readonly property string value: metric === "cpu" ? `${Math.round(SystemUsage.cpuPerc * 100)}%` : metric === "ram" ? `${Math.round(SystemUsage.memPerc * 100)}%` : metric === "disk" ? `${Math.round(SystemUsage.storagePerc * 100)}%` : `${Math.round(SystemUsage.cpuTemp)}°C`
    readonly property string label: metric === "cpu" ? qsTr("CPU") : metric === "ram" ? qsTr("Memory") : metric === "disk" ? qsTr("Disk") : qsTr("Temperature")
    readonly property string icon: metric === "cpu" ? "memory" : metric === "ram" ? "developer_board" : metric === "disk" ? "storage" : "device_thermostat"

    Ref { service: SystemUsage }

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
                MaterialIcon { text: root.icon; color: Colours.palette.m3primary }
                StyledText { Layout.fillWidth: true; text: root.label; color: Colours.palette.m3onSurfaceVariant }
                StyledText { text: root.value; color: Colours.palette.m3onSurface; font.bold: true }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Colours.palette.m3surface
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, root.percentage))
                    height: parent.height
                    radius: parent.radius
                    color: Colours.palette.m3primary
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: root.metric === "cpu" ? SystemUsage.cpuName : root.metric === "disk" ? qsTr("Mounted storage") : ""
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                elide: Text.ElideRight
            }
        }
    }
}

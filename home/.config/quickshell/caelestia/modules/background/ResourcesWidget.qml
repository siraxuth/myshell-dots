pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    implicitWidth: row.implicitWidth + Tokens.padding.large * 2
    implicitHeight: row.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.large
    color: Qt.alpha(Colours.palette.m3surface, 0.55)

    RowLayout {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.spacing.large

        Stat {
            icon: "memory"
            value: Math.round((SystemUsage.cpuPerc ?? 0) * 100) + "%"
            label: qsTr("CPU")
        }
        Stat {
            icon: "developer_board"
            value: SystemUsage.memTotal > 0 ? Math.round(SystemUsage.memUsed / SystemUsage.memTotal * 100) + "%" : "--"
            label: qsTr("RAM")
        }
        Stat {
            icon: "device_thermostat"
            value: (SystemUsage.cpuTemp ? Math.round(SystemUsage.cpuTemp) : "--") + "°"
            label: qsTr("Temp")
        }
    }

    component Stat: ColumnLayout {
        id: stat

        property string icon
        property string value
        property string label

        spacing: 0

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.small / 2

            MaterialIcon {
                text: stat.icon
                color: Colours.palette.m3primary
                font.pointSize: Tokens.font.size.large
            }
            StyledText {
                text: stat.value
                font.bold: true
                font.pointSize: Tokens.font.size.large
                color: Colours.palette.m3onSurface
            }
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: stat.label
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
        }
    }
}

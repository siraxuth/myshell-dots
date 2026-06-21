pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    property bool bgVisible: true

    implicitWidth: col.implicitWidth + Tokens.padding.large * 2
    implicitHeight: col.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.large
    color: bgVisible ? Qt.alpha(Colours.palette.m3surface, 0.45) : "transparent"

    ColumnLayout {
        id: col

        anchors.centerIn: parent
        spacing: 0

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format(GlobalConfig.services.useTwelveHourClock ? "h:mm" : "HH:mm")
            font.pointSize: Tokens.font.size.extraLarge * 2.4
            font.bold: true
            color: Colours.palette.m3onSurface
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Time.format("dddd, d MMMM")
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.normal
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    implicitWidth: layout.implicitWidth + Tokens.padding.large * 2
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2
    radius: Tokens.rounding.large
    color: Qt.alpha(Colours.palette.m3surface, 0.55)

    RowLayout {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.normal

        MaterialIcon {
            text: Weather.icon
            color: Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.extraLarge * 1.6
            fill: 1
        }

        ColumnLayout {
            spacing: 0

            StyledText {
                text: Weather.temp
                font.bold: true
                font.pointSize: Tokens.font.size.large
                color: Colours.palette.m3onSurface
            }

            StyledText {
                text: Weather.description
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
            }

            StyledText {
                visible: !!Weather.city
                text: Weather.city
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
            }
        }
    }
}

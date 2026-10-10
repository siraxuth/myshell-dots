import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import qs.services

ToolTip {
    id: root
    delay: 500
    timeout: 5000
    padding: 12
    horizontalPadding: 14
    font.family: GlobalConfig.appearance.font.family.sans
    font.pointSize: TokenConfig.appearance.fontSize.small
    palette.toolTipText: Colours.palette.m3onSurface
    palette.toolTipBase: Colours.palette.m3surfaceContainerHighest
    contentItem: RowLayout {
        spacing: 10
        Text {
            text: root.text.split(" · ")[0]
            font: root.font
            color: Colours.palette.m3onSurface
        }
        Rectangle {
            visible: root.text.includes(" · ")
            implicitWidth: shortcut.implicitWidth + 12
            implicitHeight: shortcut.implicitHeight + 6
            radius: 5
            color: Colours.palette.m3surface
            border.width: 1
            border.color: Colours.palette.m3outlineVariant
            Text {
                id: shortcut
                anchors.centerIn: parent
                text: root.text.split(" · ").slice(1).join(" · ")
                font.family: GlobalConfig.appearance.font.family.mono
                font.pointSize: TokenConfig.appearance.fontSize.small
                color: Colours.palette.m3onSurfaceVariant
            }
        }
    }
    background: Rectangle {
        radius: 10
        color: Colours.palette.m3surfaceContainerHighest
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outline, 0.6)
    }
    enter: Transition {
        NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: Math.min(160, TokenConfig.appearance.animDurations.normal)
        }
    }
    exit: Transition {
        NumberAnimation {
            property: "opacity"
            from: 1
            to: 0
            duration: Math.min(100, TokenConfig.appearance.animDurations.small)
        }
    }
}

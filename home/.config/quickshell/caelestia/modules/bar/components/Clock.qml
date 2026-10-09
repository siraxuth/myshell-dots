pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Config.bar.clock.background ? Tokens.padding.normal : Tokens.padding.small
    required property bool isHorizontal

    implicitWidth: isHorizontal ? layout.implicitWidth + root.padding * 2 : Tokens.sizes.bar.innerWidth
    implicitHeight: isHorizontal ? Tokens.sizes.bar.innerWidth : layout.implicitHeight + root.padding * 2

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.clock.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    GridLayout {
        id: layout

        anchors.centerIn: parent
        columns: root.isHorizontal ? -1 : 1
        rows: root.isHorizontal ? 1 : -1
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.small

        Loader {
            asynchronous: true
            Layout.alignment: Qt.AlignVCenter

            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                text: "calendar_month"
                color: root.colour
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter

            visible: Config.bar.clock.showDate

            horizontalAlignment: StyledText.AlignHCenter
            text: Time.format(root.isHorizontal ? "ddd d" : "ddd\nd")
            font.pointSize: Tokens.font.size.smaller
            font.family: Tokens.font.family.sans
            color: root.colour
        }

        Rectangle {
            Layout.alignment: root.isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter
            visible: Config.bar.clock.showDate
            width: root.isHorizontal ? 1 : parent.width * 0.8
            height: root.isHorizontal ? parent.height * 0.8 : 1
            color: root.colour
            opacity: 0.2
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter

            horizontalAlignment: StyledText.AlignHCenter
            text: Time.format(root.isHorizontal ? "HH:mm" : "HH\nmm")
            font.pointSize: Tokens.font.size.smaller
            font.family: Tokens.font.family.mono
            color: root.colour
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    property bool bgVisible: true
    property string variant: "digital"
    readonly property bool analog: variant === "analog" || variant === "materialAnalog" || variant === "lumen"

    implicitWidth: col.implicitWidth + Tokens.padding.large * 2
    implicitHeight: col.implicitHeight + Tokens.padding.large * 2
    radius: analog ? Math.min(width, height) / 2 : Tokens.rounding.large
    color: "transparent"
    border.width: 0

    ColumnLayout {
        id: col

        visible: !root.analog

        anchors.centerIn: parent
        spacing: 0
        width: Math.min(implicitWidth, parent.width - Tokens.padding.large * 2)

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            text: variant === "analog" || variant === "materialAnalog" ? Time.format("h:mm") : Time.format("HH:mm")
            font.pointSize: variant === "minimal" ? Tokens.font.size.extraLarge * 1.8 : Tokens.font.size.extraLarge * 2.4
            font.bold: true
            color: variant === "lumen" ? Colours.palette.m3primary : variant === "material" ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            visible: variant !== "minimal" && variant !== "analog"
            text: Time.format(variant === "materialAnalog" ? "dddd, d MMMM yyyy" : "dddd, d MMMM")
            color: variant === "material" ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.normal
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: dial
        visible: root.analog
        width: Math.min(parent.width, parent.height) - Tokens.padding.large * 2
        height: width
        anchors.centerIn: parent
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Colours.palette.m3primary

        Repeater {
            model: 12
            Rectangle {
                required property int index
                width: 3
                height: 8
                radius: 2
                color: Colours.palette.m3onSurfaceVariant
                x: (dial.width - width) / 2
                y: 7
                transformOrigin: Item.Bottom
                rotation: index * 30
            }
        }

        Rectangle {
            width: 4
            height: dial.height * 0.22
            radius: 2
            color: root.variant === "lumen" ? Colours.palette.m3primary : Colours.palette.m3onSurface
            x: (dial.width - width) / 2
            y: dial.height / 2 - height
            transformOrigin: Item.Bottom
            rotation: (Number(Time.format("h")) % 12) * 30 + Number(Time.format("m")) / 2
        }

        Rectangle {
            width: 2
            height: dial.height * 0.32
            radius: 1
            color: root.variant === "analog" ? Colours.palette.m3primary : Colours.palette.m3tertiary
            x: (dial.width - width) / 2
            y: dial.height / 2 - height
            transformOrigin: Item.Bottom
            rotation: Number(Time.format("m")) * 6
        }

        Rectangle {
            width: 9
            height: 9
            radius: width / 2
            color: Colours.palette.m3primary
            anchors.centerIn: parent
        }
    }
}

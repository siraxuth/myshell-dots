pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import Caelestia.Config
import qs.components.effects

Item {
    id: root

    default property alias contentData: content.data

    property real frameTopMargin: Tokens.padding.normal
    property real frameRightMargin: Tokens.padding.normal
    property real frameBottomMargin: Tokens.padding.normal
    property real frameLeftMargin: 0
    property real contentTopMargin: Tokens.padding.large + Tokens.padding.normal
    property real contentRightMargin: Tokens.padding.large
    property real contentBottomMargin: Tokens.padding.large + Tokens.padding.normal
    property real contentLeftMargin: Tokens.padding.large
    property real borderTopThickness: Tokens.padding.normal
    property real borderRightThickness: Tokens.padding.normal
    property real borderBottomThickness: Tokens.padding.normal
    property real borderLeftThickness: 0

    ClippingRectangle {
        id: clip

        anchors.fill: parent
        anchors.topMargin: root.frameTopMargin
        anchors.rightMargin: root.frameRightMargin
        anchors.bottomMargin: root.frameBottomMargin
        anchors.leftMargin: root.frameLeftMargin
        radius: border.innerRadius
        color: "transparent"

        Item {
            id: content

            anchors.fill: parent
            anchors.topMargin: root.contentTopMargin
            anchors.rightMargin: root.contentRightMargin
            anchors.bottomMargin: root.contentBottomMargin
            anchors.leftMargin: root.contentLeftMargin
        }
    }

    InnerBorder {
        id: border

        topThickness: root.borderTopThickness
        rightThickness: root.borderRightThickness
        bottomThickness: root.borderBottomThickness
        leftThickness: root.borderLeftThickness
    }
}

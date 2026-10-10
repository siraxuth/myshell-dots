pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property var modelData
    required property DrawerVisibilities visibilities

    implicitHeight: Tokens.sizes.launcher.itemHeight
    anchors.left: parent?.left
    anchors.right: parent?.right

    StateLayer {
        radius: Tokens.rounding.normal
        onClicked: {
            Files.open(root.modelData);
            root.visibilities.launcher = false;
        }
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.larger
        anchors.rightMargin: Tokens.padding.larger
        anchors.margins: Tokens.padding.smaller

        MaterialIcon {
            id: icon
            text: root.modelData?.isDirectory ? "folder" : "description"
            font.pointSize: Tokens.font.size.extraLarge
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            anchors.left: icon.right
            anchors.leftMargin: Tokens.spacing.normal
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.smaller / 2

            StyledText {
                width: parent.width
                text: root.modelData?.name ?? ""
                font.pointSize: Tokens.font.size.normal
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            StyledText {
                width: parent.width
                text: root.modelData?.path ?? ""
                font.pointSize: Tokens.font.size.small
                color: Colours.palette.m3outline
                elide: Text.ElideMiddle
                maximumLineCount: 1
            }
        }
    }
}

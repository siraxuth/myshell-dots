pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.utils
import qs.modules.launcher.services

Item {
    id: root

    required property DesktopEntry modelData
    required property DrawerVisibilities visibilities

    implicitHeight: Tokens.sizes.launcher.itemHeight

    anchors.left: parent?.left
    anchors.right: parent?.right

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.normal
        color: Colours.palette.m3surfaceContainerHigh
        opacity: rowState.containsMouse && !root.ListView.isCurrentItem ? 0.45 : 0

        Behavior on opacity {
            Anim { type: Anim.StandardSmall }
        }
    }

    StateLayer {
        id: rowState

        radius: Tokens.rounding.normal
        stateOpacity: pressed ? 0.1 : 0
        onClicked: {
            Apps.launch(root.modelData);
            root.visibilities.launcher = false;
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 6
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        Item {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignVCenter

            StyledRect {
                anchors.fill: parent
                radius: 8
                color: Colours.palette.m3surfaceContainerHighest
            }

            IconImage {
                anchors.centerIn: parent
                asynchronous: true
                source: Quickshell.iconPath(root.modelData?.icon, "image-missing")
                implicitSize: 24
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            StyledText {
                Layout.fillWidth: true
                text: root.modelData?.name ?? ""
                font.pointSize: Tokens.font.size.normal
                font.weight: root.ListView.isCurrentItem ? 600 : 500
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            StyledText {
                Layout.fillWidth: true
                text: (root.modelData?.comment || root.modelData?.genericName || root.modelData?.name) ?? ""
                font.pointSize: Tokens.font.size.small
                color: Colours.palette.m3outline
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            asynchronous: true
            active: root.modelData && Strings.testRegexList(GlobalConfig.launcher.favouriteApps, root.modelData.id)

            sourceComponent: MaterialIcon {
                text: "favorite"
                fill: 1
                color: Colours.palette.m3primary
            }
        }
    }
}

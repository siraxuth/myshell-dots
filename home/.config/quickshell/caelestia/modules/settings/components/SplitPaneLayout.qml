pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components

RowLayout {
    id: root

    property Component leftContent: null
    property Component rightContent: null
    property real leftWidthRatio: 0.4
    property int leftMinimumWidth: 420
    property var leftLoaderProperties: ({})
    property var rightLoaderProperties: ({})
    property alias leftLoader: leftLoader
    property alias rightLoader: rightLoader

    spacing: 0

    Item {
        id: leftPane

        Layout.preferredWidth: Math.floor(parent.width * root.leftWidthRatio)
        Layout.minimumWidth: root.leftMinimumWidth
        Layout.fillHeight: true

        PaneFrame {
            id: leftFrame

            anchors.fill: parent
            frameRightMargin: Tokens.padding.normal / 2
            contentRightMargin: Tokens.padding.large + Tokens.padding.normal / 2
            borderRightThickness: Tokens.padding.normal / 2

            Loader {
                id: leftLoader

                anchors.fill: parent
                asynchronous: true
                sourceComponent: root.leftContent

                Component.onCompleted: {
                    for (const key in root.leftLoaderProperties) {
                        leftLoader[key] = root.leftLoaderProperties[key];
                    }
                }
            }
        }

    }

    Item {
        id: rightPane

        Layout.fillWidth: true
        Layout.fillHeight: true

        PaneFrame {
            id: rightFrame

            anchors.fill: parent
            frameRightMargin: Tokens.padding.normal / 2
            contentTopMargin: Tokens.padding.large * 2
            contentRightMargin: Tokens.padding.large * 2
            contentBottomMargin: Tokens.padding.large * 2
            contentLeftMargin: Tokens.padding.large * 2
            borderLeftThickness: Tokens.padding.normal / 2

            Loader {
                id: rightLoader

                anchors.fill: parent
                asynchronous: true
                sourceComponent: root.rightContent

                Component.onCompleted: {
                    for (const key in root.rightLoaderProperties) {
                        rightLoader[key] = root.rightLoaderProperties[key];
                    }
                }
            }
        }

    }
}

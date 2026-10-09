pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    required property string screenName
    signal addRequested(string type)

    implicitHeight: 118
    radius: Tokens.rounding.large
    color: Colours.palette.m3surfaceContainer
    clip: true

    Flickable {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        contentWidth: galleryRow.implicitWidth
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Row {
            id: galleryRow
            height: parent.height
            spacing: Tokens.spacing.normal

            Repeater {
                model: WidgetRegistry.typeList()
                delegate: Item {
                    required property var modelData
                    width: 86
                    height: parent.height

                    StyledRect {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 86
                        height: 86
                        radius: Tokens.rounding.normal
                        color: Colours.palette.m3surface

                        Column {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small / 2
                            MaterialIcon { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; color: Colours.palette.m3primary; font.pointSize: Tokens.font.size.large }
                            StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.name; color: Colours.palette.m3onSurface; font.pointSize: Tokens.font.size.small; elide: Text.ElideRight }
                        }

                        StateLayer {
                            radius: parent.radius
                            disabled: !WidgetsPrefs.isReady(root.screenName)
                            onClicked: root.addRequested(modelData.id)
                        }
                    }
                }
            }
        }
    }
}

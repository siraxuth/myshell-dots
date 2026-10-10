pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Rectangle {
    id: root
    required property string screenName
    required property ShellScreen screen
    property bool running: true
    signal addRequested(string type)
    implicitHeight: 120
    radius: 12
    color: Colours.palette.m3surfaceContainerLow
    clip: true
    Flickable {
        id: scroll
        anchors.fill: parent
        anchors.margins: 8
        contentWidth: row.width
        contentHeight: height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        clip: true
        ScrollBar.horizontal: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
        Row {
            id: row
            height: scroll.height
            spacing: 8
            Repeater {
                model: WidgetRegistry.typeList()
                Rectangle {
                    id: tile
                    required property var modelData
                    width: 124
                    height: row.height
                    radius: 8
                    color: mouse.containsMouse ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3surface
                    border.width: mouse.activeFocus ? 2 : 0
                    border.color: Colours.palette.m3primary
                    clip: true
                    Item {
                        anchors.top: parent.top
                        anchors.topMargin: 6
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 104
                        height: Math.max(32, tile.height - 38)
                        Loader {
                            anchors.centerIn: parent
                            active: root.running && root.screen !== null && tile.x + tile.width >= scroll.contentX && tile.x <= scroll.contentX + scroll.width
                            sourceComponent: Widget {
                                widget: ({
                                        wId: "preview",
                                        wType: tile.modelData.id,
                                        wVariant: tile.modelData.variant,
                                        wWidth: tile.modelData.size[0],
                                        wHeight: tile.modelData.size[1],
                                        wProps: {
                                            bgRadius: 16,
                                            bgOpacity: 1
                                        }
                                    })
                                screen: root.screen
                                preview: true
                                enabled: false
                                scale: Math.min(100 / width, Math.max(32, tile.height - 38) / height)
                            }
                        }
                    }
                    StyledText {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 8
                        text: tile.modelData.name
                        horizontalAlignment: Text.AlignHCenter
                        font.pointSize: Tokens.font.size.small
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        enabled: root.enabled
                        hoverEnabled: true
                        activeFocusOnTab: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: qsTr("Add %1").arg(tile.modelData.name)
                        onClicked: root.addRequested(tile.modelData.id)
                        Keys.onReturnPressed: root.addRequested(tile.modelData.id)
                        Keys.onSpacePressed: root.addRequested(tile.modelData.id)
                        WidgetTooltip {
                            visible: mouse.containsMouse || mouse.activeFocus
                            text: qsTr("Add %1").arg(tile.modelData.name)
                        }
                    }
                }
            }
        }
    }
}

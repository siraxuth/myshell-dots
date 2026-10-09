pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.settings

Item {
    id: root

    required property ShellScreen screen
    required property Session session
    required property bool initialOpeningComplete

    implicitWidth: layout.implicitWidth + Tokens.padding.larger * 4
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    Flickable {
        id: flick

        anchors.fill: parent
        contentHeight: layout.implicitHeight
        contentWidth: width
        flickableDirection: Flickable.VerticalFlick
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        // Keep wheel events in the navigation rail so the adjacent pane cannot
        // interpret them as a page change or scroll gesture.
        MouseArea {
            anchors.fill: parent
            z: 10
            acceptedButtons: Qt.NoButton
            preventStealing: true

            onWheel: event => {
                const delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 64;
                flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY - delta));
                event.accepted = true;
            }
        }

        StyledScrollBar.vertical: StyledScrollBar {
            flickable: flick
        }

        ColumnLayout {
            id: layout

            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.larger * 2
            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.larger * 2
            // centre when everything fits; top-align + scroll when it doesn't
            y: Math.max(0, (flick.height - implicitHeight) / 2)
            spacing: Tokens.spacing.normal

        states: State {
            name: "expanded"
            when: root.session.navExpanded

            PropertyChanges {
                layout.spacing: root.Tokens.spacing.small
            }
        }

        transitions: Transition {
            Anim {
                properties: "spacing"
            }
        }

        Repeater {
            model: PaneRegistry.categories

            Item {
                id: category

                required property var modelData

                Layout.fillWidth: true
                implicitWidth: categoryLayout.implicitWidth
                implicitHeight: categoryLayout.implicitHeight

                ColumnLayout {
                    id: categoryLayout

                    anchors.fill: parent
                    spacing: 0

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: category.width * 0.5
                        Layout.topMargin: category.modelData.name !== PaneRegistry.categories[0].name ? Tokens.spacing.small : 0
                        Layout.bottomMargin: category.modelData.name !== PaneRegistry.categories[0].name ? Tokens.spacing.small : 0
                        implicitHeight: 1
                        color: Qt.alpha(Colours.palette.m3outline, 0.24)
                        visible: category.modelData.name !== PaneRegistry.categories[0].name
                    }

                    Repeater {
                        model: category.modelData.paneIds

                        NavItem {
                            required property int index
                            required property string modelData

                            Layout.fillWidth: true
                            pane: PaneRegistry.getById(modelData)
                            firstInGroup: index === 0
                            lastInGroup: index === category.modelData.paneIds.length - 1
                        }
                    }
                }
            }
        }
        }
    }

    component NavItem: Item {
        id: item

        required property var pane
        required property bool firstInGroup
        required property bool lastInGroup
        readonly property bool active: root.session.active === pane.label

        implicitWidth: contentRow.implicitWidth + Tokens.padding.normal * 2
        implicitHeight: contentRow.implicitHeight + Tokens.padding.small * 2

        StyledRect {
            id: background

            anchors.fill: parent
            topLeftRadius: stateLayer.containsMouse ? Tokens.rounding.small : item.firstInGroup ? Tokens.rounding.small : 0
            topRightRadius: stateLayer.containsMouse ? Tokens.rounding.small : item.firstInGroup ? Tokens.rounding.small : 0
            bottomLeftRadius: stateLayer.containsMouse ? Tokens.rounding.small : item.lastInGroup ? Tokens.rounding.small : 0
            bottomRightRadius: stateLayer.containsMouse ? Tokens.rounding.small : item.lastInGroup ? Tokens.rounding.small : 0
            color: item.active ? Colours.palette.m3surfaceContainerLowest : Qt.alpha(Colours.palette.m3surfaceContainerHigh, 0.35)
            border.width: stateLayer.containsMouse ? 1 : 0
            border.color: Qt.alpha(Colours.palette.m3primary, 0.75)

            StateLayer {
                id: stateLayer

                onClicked: {
                    // Prevent tab switching during initial opening animation to avoid blank pages
                    if (!root.initialOpeningComplete) {
                        return;
                    }
                    root.session.active = item.pane.label;
                }

                color: item.active ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
            }

            RowLayout {
                id: contentRow

                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.normal
                anchors.rightMargin: Tokens.padding.normal
                spacing: Tokens.spacing.normal

                MaterialIcon {
                    text: item.pane.icon
                    color: item.active ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.large
                    fill: item.active ? 1 : 0

                    Behavior on fill {
                        Anim {}
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.smaller

                    StyledText {
                        Layout.fillWidth: true
                        text: item.pane.label
                        color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                        font.capitalization: Font.Capitalize
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: item.pane.description
                        color: Qt.alpha(item.active ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant, 0.62)
                        font.pointSize: Tokens.font.size.smaller
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}

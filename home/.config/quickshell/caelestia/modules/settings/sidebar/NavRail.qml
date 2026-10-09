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

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.normal

        StyledRect {
            id: searchBackground

            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.larger * 2
            Layout.rightMargin: Tokens.padding.larger * 2
            Layout.topMargin: Tokens.padding.large
            implicitHeight: searchRow.implicitHeight + Tokens.padding.small * 2

            radius: Tokens.rounding.normal
            color: Colours.palette.m3surfaceContainerLowest
            border.width: 1
            border.color: searchField.activeFocus ? Colours.palette.m3primary : Colours.palette.m3outlineVariant

            RowLayout {
                id: searchRow

                anchors.fill: parent
                anchors.leftMargin: Tokens.padding.larger
                anchors.rightMargin: Tokens.padding.small
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "search"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.normal
                }

                StyledTextField {
                    id: searchField

                    Layout.fillWidth: true
                    placeholderText: qsTr("Search settings")
                    font.pointSize: Tokens.font.size.normal
                    selectByMouse: true
                }

                IconButton {
                    visible: searchField.text.length > 0
                    type: IconButton.Text
                    icon: "close"
                    font.pointSize: Tokens.font.size.normal
                    Accessible.name: qsTr("Clear search")
                    onClicked: searchField.clear()
                }
            }
        }

        Flickable {
            id: flick

            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: layout.implicitHeight + Tokens.padding.large * 2
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
            // Keep the list top-aligned while allowing only this column to scroll.
            y: Tokens.padding.large
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
                required property int index

                readonly property var matchingPaneIds: modelData.paneIds.filter(id => {
                    const pane = PaneRegistry.getById(id);
                    const query = searchField.text.trim().toLocaleLowerCase();
                    return !query || `${pane.label} ${pane.description}`.toLocaleLowerCase().includes(query);
                })

                Layout.fillWidth: true
                Layout.topMargin: index > 0 ? Tokens.spacing.small : 0
                visible: matchingPaneIds.length > 0
                implicitWidth: categoryLayout.implicitWidth + Tokens.padding.small * 2
                implicitHeight: categoryLayout.implicitHeight + Tokens.padding.small * 2

                Rectangle {
                    anchors.fill: parent
                    radius: Tokens.rounding.large
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(Colours.palette.m3outline, 0.2)
                }

                ColumnLayout {
                    id: categoryLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    spacing: 0

                    Repeater {
                        model: category.matchingPaneIds

                        NavItem {
                            required property int index
                            required property string modelData

                            Layout.fillWidth: true
                            pane: PaneRegistry.getById(modelData)
                            firstInGroup: index === 0
                            lastInGroup: index === category.matchingPaneIds.length - 1
                        }
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

        implicitWidth: contentRow.implicitWidth + Tokens.padding.large * 2
        implicitHeight: contentRow.implicitHeight + Tokens.padding.large * 2

        StyledRect {
            id: background

            anchors.fill: parent
            topLeftRadius: stateLayer.pressed || stateLayer.containsMouse ? Tokens.rounding.normal : item.active || item.firstInGroup ? Tokens.rounding.large : 0
            topRightRadius: stateLayer.pressed || stateLayer.containsMouse ? Tokens.rounding.normal : item.active || item.firstInGroup ? Tokens.rounding.large : 0
            bottomLeftRadius: stateLayer.pressed || stateLayer.containsMouse ? Tokens.rounding.normal : item.active || item.lastInGroup ? Tokens.rounding.large : 0
            bottomRightRadius: stateLayer.pressed || stateLayer.containsMouse ? Tokens.rounding.normal : item.active || item.lastInGroup ? Tokens.rounding.large : 0
            color: item.active ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

            Behavior on topLeftRadius { Anim { type: Anim.StandardSmall } }
            Behavior on topRightRadius { Anim { type: Anim.StandardSmall } }
            Behavior on bottomLeftRadius { Anim { type: Anim.StandardSmall } }
            Behavior on bottomRightRadius { Anim { type: Anim.StandardSmall } }

            StateLayer {
                id: stateLayer

                topLeftRadius: background.topLeftRadius
                topRightRadius: background.topRightRadius
                bottomLeftRadius: background.bottomLeftRadius
                bottomRightRadius: background.bottomRightRadius

                onClicked: {
                    // Prevent tab switching during initial opening animation to avoid blank pages
                    if (!root.initialOpeningComplete) {
                        return;
                    }
                    root.session.active = item.pane.label;
                }

                color: item.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
            }

            RowLayout {
                id: contentRow

                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.normal

                StyledRect {
                    Layout.fillHeight: true
                    Layout.topMargin: -1
                    Layout.bottomMargin: -1
                    implicitWidth: height

                    radius: Tokens.rounding.full
                    color: item.active ? Colours.palette.m3primary : Colours.palette.m3secondaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 1

                        text: item.pane.icon
                        color: item.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSecondaryContainer
                        font.pointSize: Tokens.font.size.large
                        fill: item.active ? 1 : 0

                        Behavior on fill {
                            Anim {}
                        }
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
                        font.pointSize: Tokens.font.size.normal
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: item.pane.description
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.smaller
                        maximumLineCount: 1
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}

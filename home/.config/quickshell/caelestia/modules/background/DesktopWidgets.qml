pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Renders WidgetsPrefs.widgets on the wallpaper, GROUPED by position: widgets sharing a corner
// stack in a column (no overlap), so e.g. clock + weather both at top-left flow under each other.
Item {
    id: root

    anchors.fill: parent

    readonly property var positions: ["top-left", "top-center", "top-right", "middle-left", "middle-center", "middle-right", "bottom-left", "bottom-center", "bottom-right"]

    Repeater {
        model: root.positions

        Item {
            id: slot

            required property string modelData

            readonly property var items: (WidgetsPrefs.widgets || []).filter(w => (w.position ?? "bottom-left") === modelData && (w.enabled ?? true))

            visible: items.length > 0
            implicitWidth: stack.implicitWidth
            implicitHeight: stack.implicitHeight

            anchors.margins: Tokens.padding.large * 2
            anchors.leftMargin: Tokens.padding.large * 2 + Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.smaller, Config.border.thickness)

            state: modelData
            states: [
                State {
                    name: "top-left"
                    AnchorChanges {
                        target: slot
                        anchors.top: parent.top
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "top-center"
                    AnchorChanges {
                        target: slot
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "top-right"
                    AnchorChanges {
                        target: slot
                        anchors.top: parent.top
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "middle-left"
                    AnchorChanges {
                        target: slot
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "middle-center"
                    AnchorChanges {
                        target: slot
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "middle-right"
                    AnchorChanges {
                        target: slot
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                    }
                },
                State {
                    name: "bottom-left"
                    AnchorChanges {
                        target: slot
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                    }
                },
                State {
                    name: "bottom-center"
                    AnchorChanges {
                        target: slot
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                },
                State {
                    name: "bottom-right"
                    AnchorChanges {
                        target: slot
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                    }
                }
            ]

            Column {
                id: stack

                spacing: Tokens.spacing.large

                Repeater {
                    model: slot.items

                    Loader {
                        id: wl

                        required property var modelData

                        anchors.horizontalCenter: slot.modelData.endsWith("-center") ? parent.horizontalCenter : undefined
                        scale: modelData.scale ?? 1.0
                        transformOrigin: Item.Center
                        sourceComponent: ({
                                media: mediaComp,
                                weather: weatherComp,
                                clock: clockComp,
                                arch: archComp,
                                resources: resComp
                            })[modelData.type] ?? mediaComp

                        Binding {
                            target: wl.item
                            property: "bgVisible"
                            value: wl.modelData.background ?? true
                            when: wl.item !== null
                        }
                    }
                }
            }
        }
    }

    Component {
        id: mediaComp
        MediaWidget {}
    }
    Component {
        id: weatherComp
        WeatherWidget {}
    }
    Component {
        id: clockComp
        ClockWidget {}
    }
    Component {
        id: archComp
        ArchWidget {}
    }
    Component {
        id: resComp
        ResourcesWidget {}
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// Renders the configurable desktop widgets (Config.background.widgets) on the wallpaper.
// Each entry: { type: "media"|"weather", enabled, position: top/middle/bottom-left/center/right, scale }.
Item {
    id: root

    anchors.fill: parent

    Repeater {
        model: WidgetsPrefs.widgets

        Loader {
            id: slot

            required property var modelData

            active: modelData.enabled ?? true
            visible: active
            asynchronous: true
            scale: modelData.scale ?? 1.0

            anchors.margins: Tokens.padding.large * 2
            anchors.leftMargin: Tokens.padding.large * 2 + Tokens.sizes.bar.innerWidth + Math.max(Tokens.padding.smaller, Config.border.thickness)

            sourceComponent: ({
                    media: mediaComp,
                    weather: weatherComp,
                    clock: clockComp,
                    arch: archComp,
                    resources: resComp
                })[modelData.type] ?? mediaComp

            state: modelData.position ?? "bottom-left"
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

            transitions: Transition {
                AnchorAnim {}
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

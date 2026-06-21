pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Caelestia.Services
import qs.components
import qs.services

// Arch logo with a pulsing coloured glow, gentle breathing, and a circular audio-reactive
// ring (cava spectrum) orbiting it — a centerpiece for mid-screen.
Item {
    id: root

    readonly property string logo: "file:///usr/share/pixmaps/archlinux-logo.svg"
    readonly property real ringRadius: 122
    property bool bgVisible: true // unused (logo has no card bg) — present so the loader Binding has a target

    implicitWidth: 420
    implicitHeight: 420

    // keep cava running while this widget exists
    ServiceRef {
        service: Audio.cava
    }

    // circular spectrum ring
    Item {
        id: ring

        anchors.centerIn: parent

        Repeater {
            model: Audio.cava.values

            Item {
                id: spoke

                required property int index
                required property real modelData

                anchors.centerIn: parent
                rotation: index * 360 / Math.max(1, Audio.cava.values.length)

                Rectangle {
                    width: 3
                    radius: 1.5
                    height: 5 + Math.max(0, spoke.modelData) * 80
                    antialiasing: true
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -root.ringRadius - height
                    color: Colours.palette.m3primary
                    opacity: 0.85

                    Behavior on height {
                        NumberAnimation {
                            duration: 90
                            easing.type: Easing.OutQuad
                        }
                    }
                }
            }
        }
    }

    // pulsing colour glow behind (colorised + blurred copy of the logo)
    Image {
        id: glow

        anchors.centerIn: parent
        source: root.logo
        sourceSize.width: 240
        sourceSize.height: 240
        width: 220
        height: 220
        fillMode: Image.PreserveAspectFit
        smooth: true

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            colorization: 1.0
            colorizationColor: Colours.palette.m3primary
            brightness: 0.2
        }

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: true
            NumberAnimation {
                from: 0.25
                to: 0.85
                duration: 1800
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: 0.85
                to: 0.25
                duration: 1800
                easing.type: Easing.InOutSine
            }
        }
        SequentialAnimation on scale {
            loops: Animation.Infinite
            running: true
            NumberAnimation {
                from: 1.0
                to: 1.18
                duration: 3600
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: 1.18
                to: 1.0
                duration: 3600
                easing.type: Easing.InOutSine
            }
        }
    }

    // crisp logo on top (natural Arch colours), gentle breathing
    Image {
        id: logoImg

        anchors.centerIn: parent
        source: root.logo
        sourceSize.width: 240
        sourceSize.height: 240
        width: 200
        height: 200
        fillMode: Image.PreserveAspectFit
        smooth: true

        SequentialAnimation on scale {
            loops: Animation.Infinite
            running: true
            NumberAnimation {
                from: 1.0
                to: 1.05
                duration: 3600
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                from: 1.05
                to: 1.0
                duration: 3600
                easing.type: Easing.InOutSine
            }
        }
    }
}

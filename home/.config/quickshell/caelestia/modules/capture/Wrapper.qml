pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.services

Item {
    id: root

    required property DrawerVisibilities visibilities

    readonly property bool needsKeyboard: visibilities.capture
    readonly property bool shouldBeActive: visibilities.capture
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    anchors.topMargin: (-implicitHeight - 5) * offsetScale
    width: implicitWidth
    height: implicitHeight
    implicitHeight: content.implicitHeight
    implicitWidth: Math.min(620, parent.width > 0 ? parent.width : 620)
    opacity: 1 - offsetScale

    Connections {
        target: root.visibilities
        function onCaptureChanged(): void {
            if (!root.visibilities.capture && !CaptureSession.dispatching)
                CaptureSession.discardSession();
        }
    }

    Behavior on offsetScale {
        enabled: !CaptureSession.dispatching
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Loader {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: parent.width

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            visibilities: root.visibilities
        }
    }
}

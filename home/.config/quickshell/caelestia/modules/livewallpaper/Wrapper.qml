pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components

// Top-anchored drawer panel for the live-wallpaper picker. Mirrors dashboard/Wrapper.qml
// so it slides down from the top and shares the drawer's blob background exactly.
Item {
    id: root

    required property DrawerVisibilities visibilities

    readonly property bool needsKeyboard: visibilities.liveWallpaper
    readonly property bool shouldBeActive: visibilities.liveWallpaper
    readonly property real nonAnimHeight: shouldBeActive ? ((content.item as Content)?.nonAnimHeight ?? 0) : 0

    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    anchors.topMargin: (-implicitHeight - 5) * offsetScale
    implicitHeight: content.implicitHeight
    implicitWidth: content.implicitWidth || 854
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Loader {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            visibilities: root.visibilities
        }
    }
}

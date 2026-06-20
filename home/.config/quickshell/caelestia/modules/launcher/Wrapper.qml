pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property var panels

    readonly property bool shouldBeActive: visibilities.launcher && Config.launcher.enabled
    readonly property bool centered: LauncherPrefs.position === "center"
    readonly property bool atTop: LauncherPrefs.position === "top"

    readonly property real maxHeight: {
        let max = screen.height - Config.border.thickness * 2 - Tokens.spacing.large;
        if (visibilities.dashboard)
            max -= panels.dashboard.nonAnimHeight;
        return max;
    }

    property real offsetScale: shouldBeActive ? 0 : 1

    // NOTE: stock caelestia froze implicitHeight on close ("break binding during close anim").
    // That left the panel's blob background alive at a fixed height when closed, so at the top
    // position it bled back into view as a blank rounded frame. The content Loader already stays
    // active during the close anim (via `visible`), so the slide is smooth WITHOUT the freeze,
    // and when fully closed the height collapses to 0 like the dashboard → blob fully gone.
    visible: offsetScale < 1
    anchors.bottomMargin: (centered || atTop) ? 0 : (-implicitHeight - 5) * offsetScale
    // dashOffset must vanish when closed (offsetScale=1), else a closed (empty, height-frozen)
    // launcher gets pushed into view as a blank frame whenever the dashboard is hovered.
    anchors.topMargin: atTop ? ((-implicitHeight - 5) * offsetScale + (visibilities.dashboard ? panels.dashboard.nonAnimHeight : 0) * (1 - offsetScale)) : 0
    // Center doesn't slide off-screen (it fades), and the blob background doesn't fade with it —
    // so shrink the panel height as it closes, making the blob shrink away instead of lingering
    // as a blank rounded frame. Top/bottom slide off via margins, so they keep full height.
    implicitHeight: content.implicitHeight * (centered ? 1 - offsetScale : 1)
    implicitWidth: content.implicitWidth || 630 // Hard coded fallback for first open
    opacity: 1 - offsetScale
    // Center pops/expands out from the screen centre: a bigger scale delta (0.8 → 1) plus the
    // expressive spatial easing on offsetScale gives a springy grow. Top/bottom keep scale 1.
    transformOrigin: Item.Center
    scale: centered ? 1 - offsetScale * 0.2 : 1

    transform: Translate {
        y: root.centered ? 18 * root.offsetScale : 0
    }

    Component.onCompleted: Qt.callLater(() => Apps) // Load apps on init

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            visibilities: root.visibilities
            panels: root.panels
            maxHeight: root.maxHeight
        }
    }
}

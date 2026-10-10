pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.utils

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property bool onLeft
    required property ShellScreen screen
    readonly property bool needsKeyboard: (content.item as Content)?.needsKeyboard ?? false
    readonly property DashboardState dashState: DashboardState {
        reloadableId: "dashboardState"
    }
    readonly property ScreenState screenState: ScreenState {
        reloadableId: `screenState-${root.screen.name}`
        modelData: root.screen
        visibilities: root.visibilities
        dashboardState: root.dashState
    }
    readonly property FileDialog facePicker: FileDialog {
        title: qsTr("Select a profile picture")
        filterLabel: qsTr("Image files")
        filters: Images.validImageExtensions
        onAccepted: path => {
            if (CUtils.copyFile(Qt.resolvedUrl(path), Qt.resolvedUrl(`${Paths.home}/.face`)))
                Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "low", "-h", `STRING:image-path:${path}`, "Profile picture changed", `Profile picture changed to ${Paths.shortenHome(path)}`]);
            else
                Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "critical", "Unable to change profile picture", `Failed to change profile picture to ${Paths.shortenHome(path)}`]);
        }
    }

    readonly property real nonAnimHeight: state === "visible" ? ((content.item as Content)?.nonAnimHeight ?? 0) : 0
    readonly property bool shouldBeActive: visibilities.dashboard && Config.dashboard.enabled
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    x: root.onLeft ? (-implicitWidth - 5) * offsetScale : (parent.width - width) / 2
    y: root.onLeft ? (parent.height - height) / 2 : (-implicitHeight - 5) * offsetScale
    width: implicitWidth
    height: implicitHeight
    implicitHeight: content.implicitHeight
    implicitWidth: content.implicitWidth || 854 // Hard coded fallback for first open
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Loader {
        id: content

        x: root.onLeft ? parent.width - width : (parent.width - width) / 2
        y: root.onLeft ? (parent.height - height) / 2 : parent.height - height

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            visibilities: root.visibilities
            dashState: root.dashState
            screenState: root.screenState
            facePicker: root.facePicker
        }
    }
}

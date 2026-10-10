import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar as Bar
import qs.modules.dashboard as Dashboard
import qs.modules.livewallpaper as LiveWp
import qs.modules.capture as Capture
import qs.modules.launcher as Launcher
import qs.modules.notifications as Notifications
import qs.modules.osd as Osd
import qs.modules.session as Session
import qs.modules.sidebar as Sidebar
import qs.modules.utilities as Utilities
import qs.modules.bar.popouts as BarPopouts
import qs.modules.utilities.toasts as Toasts
import qs.utils

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property Bar.BarWrapper bar
    required property real borderThickness

    readonly property bool barOnRight: BarPosition.isRight(bar.position)
    readonly property bool barOnBottom: BarPosition.isBottom(bar.position)

    readonly property alias osd: osd
    readonly property alias osdWrapper: osdWrapper
    readonly property alias notifications: notifications
    readonly property alias session: session
    readonly property alias sessionWrapper: sessionWrapper
    readonly property alias launcher: launcher
    readonly property alias dashboard: dashboard
    readonly property alias liveWallpaper: liveWallpaper
    readonly property alias capture: capture
    readonly property alias popouts: popoutsWrapper.content
    readonly property alias popoutsWrapper: popoutsWrapper
    readonly property alias utilities: utilities
    readonly property alias toasts: toasts
    readonly property alias sidebar: sidebar

    anchors.fill: parent
    anchors.margins: borderThickness
    anchors.leftMargin: bar.reservedLeft
    anchors.rightMargin: bar.reservedRight
    anchors.topMargin: bar.reservedTop
    anchors.bottomMargin: bar.reservedBottom

    Item {
        id: osdWrapper

        anchors.verticalCenter: parent.verticalCenter
        x: root.barOnRight ? sessionWrapper.width * (1 - session.offsetScale) : parent.width - width - sessionWrapper.width * (1 - session.offsetScale)
        clip: sidebar.visible || session.visible

        implicitWidth: osd.implicitWidth * (1 - osd.offsetScale)
        implicitHeight: osd.implicitHeight

        Osd.Wrapper {
            id: osd

            screen: root.screen
            visibilities: root.visibilities
            sidebarOrSessionVisible: sidebar.visible || session.visible

            anchors.verticalCenter: parent.verticalCenter
            x: root.barOnRight ? slideOffset : parent.width - width - slideOffset
        }
    }

    Notifications.Wrapper {
        id: notifications

        visibilities: root.visibilities
        sidebarPanel: sidebar
        osdPanel: osdWrapper
        sessionPanel: sessionWrapper

        anchors.top: root.barOnBottom ? utilities.bottom : parent.top
        anchors.topMargin: -5
        x: root.barOnRight ? 0 : parent.width - width
    }

    Item {
        id: sessionWrapper

        anchors.verticalCenter: parent.verticalCenter
        x: root.barOnRight ? sidebar.width * (1 - sidebar.offsetScale) : parent.width - width - sidebar.width * (1 - sidebar.offsetScale)
        clip: sidebar.visible

        implicitWidth: session.implicitWidth * (1 - session.offsetScale)
        implicitHeight: session.implicitHeight

        Session.Wrapper {
            id: session

            visibilities: root.visibilities
            sidebarVisible: sidebar.visible

            anchors.verticalCenter: parent.verticalCenter
            x: root.barOnRight ? slideOffset : parent.width - width - slideOffset
        }
    }

    Launcher.Wrapper {
        id: launcher

        screen: root.screen
        visibilities: root.visibilities
        panels: root

        // Set exactly ONE vertical anchor per position. Conditional `? : undefined` anchor
        // bindings don't reliably clear when switching position — QML kept both top & bottom
        // anchored, stretching the panel to full height so its blob showed as a full-screen
        // empty frame. Clearing all three then setting one imperatively avoids that.
        function applyVAnchor(): void {
            anchors.top = undefined;
            anchors.bottom = undefined;
            anchors.verticalCenter = undefined;
            const p = LauncherPrefs.position;
            if (p === "top")
                anchors.top = parent.top;
            else if (p === "center")
                anchors.verticalCenter = parent.verticalCenter;
            else
                anchors.bottom = parent.bottom;
        }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: LauncherPrefs.position === "center" && BarPosition.isLeft(bar.position) ? -bar.implicitWidth / 2 : 0

        Component.onCompleted: applyVAnchor()

        Connections {
            target: LauncherPrefs
            function onPositionChanged(): void {
                launcher.applyVAnchor();
            }
        }
    }

    Dashboard.Wrapper {
        id: dashboard

        screen: root.screen
        visibilities: root.visibilities
        onLeft: bar.isHorizontal
    }

    LiveWp.Wrapper {
        id: liveWallpaper

        visibilities: root.visibilities

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }

    Capture.Wrapper {
        id: capture

        visibilities: root.visibilities

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }

    BarPopouts.ClipWrapper {
        id: popoutsWrapper

        screen: root.screen
        borderThickness: root.borderThickness
        position: bar.position
    }

    Utilities.Wrapper {
        id: utilities

        visibilities: root.visibilities
        sidebar: sidebar
        popouts: popoutsWrapper.content

        y: root.barOnBottom ? slideOffset : parent.height - height - slideOffset
        x: root.barOnRight ? 0 : parent.width - width
        height: implicitHeight
    }

    Toasts.Toasts {
        id: toasts

        anchors.bottom: root.barOnBottom || sidebar.visible ? parent.bottom : utilities.top
        x: root.barOnRight ? sidebar.x + sidebar.width + anchors.margins : sidebar.x - width - anchors.margins
        anchors.margins: Tokens.padding.normal
    }

    Sidebar.Wrapper {
        id: sidebar

        visibilities: root.visibilities

        anchors.top: notifications.bottom
        anchors.bottom: root.barOnBottom ? parent.bottom : utilities.top
        x: root.barOnRight ? slideOffset : parent.width - width - slideOffset
    }
}

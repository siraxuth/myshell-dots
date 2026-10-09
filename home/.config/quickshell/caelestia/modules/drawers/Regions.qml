pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.modules.bar as Bar
import qs.services

Region {
    id: root

    required property Bar.BarWrapper bar
    required property Panels panels
    required property var win

    readonly property real borderThickness: win.contentItem.Config.border.thickness
    readonly property real clampedThickness: win.contentItem.Config.border.clampedThickness

    x: bar.reservedLeft + win.dragMaskPadding
    y: bar.reservedTop + win.dragMaskPadding
    width: win.width - bar.reservedLeft - bar.reservedRight - win.dragMaskPadding * 2
    height: win.height - bar.reservedTop - bar.reservedBottom - win.dragMaskPadding * 2
    intersection: Intersection.Xor

    R {
        panel: root.panels.dashboard
        // Add the dashboard bounds to the input region while hover-open. Its
        // left edge can sit outside the normal interaction area, especially
        // when dragMaskPadding is active; without this, moving into the panel
        // makes Interactions lose containsMouse and immediately hides it.
        intersection: root.panels.dashboard.visible && root.win.contentItem.Config.dashboard.showOnHover
            ? Intersection.Union
            : Intersection.Subtract
        y: 0
        height: panel.height * (1 - root.panels.dashboard.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.liveWallpaper
        y: 0
        height: panel.height * (1 - root.panels.liveWallpaper.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.launcher
        y: LauncherPrefs.position === "bottom" ? root.win.height - height : panel.y + root.borderThickness
        height: panel.height * (1 - root.panels.launcher.offsetScale) + root.borderThickness
    }

    R {
        id: sessionRegion

        panel: root.panels.sessionWrapper
        x: root.win.width - width
        width: panel.width * (1 - root.panels.session.offsetScale) + root.borderThickness + sidebarRegion.width
    }

    R {
        id: sidebarRegion

        panel: root.panels.sidebar
        x: root.win.width - width
        width: panel.width * (1 - root.panels.sidebar.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.osdWrapper
        x: root.win.width - width
        width: panel.width * (1 - root.panels.osd.offsetScale) + root.borderThickness + sessionRegion.width
    }

    R {
        panel: root.panels.notifications
        y: 0
        height: panel.height + root.borderThickness
    }

    R {
        panel: root.panels.utilities
        y: root.win.height - height
        height: panel.height * (1 - root.panels.utilities.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.popoutsWrapper
        width: panel.width * (1 - root.panels.popoutsWrapper.offsetScale)
    }

    component R: Region {
        required property Item panel

        x: panel.x + root.bar.reservedLeft
        y: panel.y + root.bar.reservedTop
        width: panel.width
        height: panel.height
        intersection: Intersection.Subtract
    }
}

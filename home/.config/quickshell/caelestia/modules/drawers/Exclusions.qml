pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components.containers
import qs.modules.bar as Bar
import qs.utils

Scope {
    id: root

    required property ShellScreen screen
    required property Bar.BarWrapper bar

    ExclusionZone {
        hasBar: BarPosition.isLeft(root.bar.position)
        anchors.left: true
    }

    ExclusionZone {
        hasBar: BarPosition.isTop(root.bar.position)
        anchors.top: true
    }

    ExclusionZone {
        hasBar: false
        anchors.right: true
    }

    ExclusionZone {
        hasBar: BarPosition.isBottom(root.bar.position)
        anchors.bottom: true
    }

    component ExclusionZone: StyledWindow {
        property bool hasBar

        screen: root.screen
        name: "border-exclusion"
        exclusiveZone: hasBar ? root.bar.exclusiveZone : contentItem.Config.border.thickness
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.utils
import qs.services
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    readonly property bool disabled: Strings.testRegexList(Config.bar.excludedScreens, screen.name)
    readonly property string position: BarPositionPrefs.position
    readonly property bool isHorizontal: BarPosition.isHorizontal(position)

    property real extent: fullscreen ? 0 : Config.border.thickness
    readonly property int clampedWidth: Math.max(Config.border.minThickness, extent)
    readonly property int clampedHeight: Math.max(Config.border.minThickness, extent)
    readonly property int reservedLeft: BarPosition.isLeft(position) ? clampedWidth : Config.border.thickness
    readonly property int reservedRight: BarPosition.isRight(position) ? clampedWidth : Config.border.thickness
    readonly property int reservedTop: BarPosition.isTop(position) ? clampedHeight : Config.border.thickness
    readonly property int reservedBottom: BarPosition.isBottom(position) ? clampedHeight : Config.border.thickness
    readonly property int padding: Math.max(Tokens.padding.smaller, Config.border.thickness)
    readonly property int contentWidth: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property int contentHeight: contentWidth
    readonly property int contentThickness: contentWidth
    readonly property int exclusiveZone: !disabled && (Config.bar.persistent || visibilities.bar) ? contentThickness : Config.border.thickness
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (Config.bar.persistent || visibilities.bar || isHovered)
    property bool isHovered

    function closeTray(): void {
        (content.item as Bar)?.closeTray();
    }

    function checkPopout(y: real): void {
        (content.item as Bar)?.checkPopout(y);
    }

    function handleWheel(y: real, angleDelta: point): void {
        (content.item as Bar)?.handleWheel(y, angleDelta);
    }

    clip: true
    visible: extent > 0
    implicitWidth: isHorizontal ? screen.width : extent
    implicitHeight: isHorizontal ? extent : screen.height

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            root.extent: root.contentThickness
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "extent"
                type: Anim.DefaultSpatial
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "extent"
                type: Anim.Emphasized
            }
        }
    ]

    Loader {
        id: content

        x: root.isHorizontal ? 0 : parent.width - width
        y: root.isHorizontal && BarPosition.isBottom(root.position) ? parent.height - height : 0
        width: root.isHorizontal ? root.screen.width : root.contentThickness
        height: root.isHorizontal ? root.contentThickness : root.screen.height

        active: root.shouldBeVisible || root.visible

        sourceComponent: Bar {
            width: root.isHorizontal ? root.screen.width : root.contentThickness
            height: root.isHorizontal ? root.contentThickness : root.screen.height
            isHorizontal: root.isHorizontal
            screen: root.screen
            visibilities: root.visibilities
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }
}

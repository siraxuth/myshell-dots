pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property ShellScreen screen
    required property bool isHorizontal
    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property string activeSpecial: (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? monitor : Hypr.focusedMonitor)?.lastIpcObject.specialWorkspace?.name ?? ""

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: mask
    }

    Item {
        id: mask

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            anchors.fill: parent
            radius: Tokens.rounding.full

            gradient: Gradient {
            orientation: root.isHorizontal ? Gradient.Horizontal : Gradient.Vertical

                GradientStop {
                    position: 0
                    color: Qt.rgba(0, 0, 0, 0)
                }
                GradientStop {
                    position: 0.3
                    color: Qt.rgba(0, 0, 0, 1)
                }
                GradientStop {
                    position: 0.7
                    color: Qt.rgba(0, 0, 0, 1)
                }
                GradientStop {
                    position: 1
                    color: Qt.rgba(0, 0, 0, 0)
                }
            }
        }

        Rectangle {
            x: 0
            y: 0
            width: root.isHorizontal ? parent.width / 2 : parent.width
            height: root.isHorizontal ? parent.height : parent.height / 2
            radius: Tokens.rounding.full
            opacity: (root.isHorizontal ? view.contentX : view.contentY) > 0 ? 0 : 1

            Behavior on opacity {
                Anim {}
            }
        }

        Rectangle {
            x: root.isHorizontal ? parent.width - width : 0
            y: root.isHorizontal ? 0 : parent.height - height
            width: root.isHorizontal ? parent.width / 2 : parent.width
            height: root.isHorizontal ? parent.height : parent.height / 2
            radius: Tokens.rounding.full
            opacity: root.isHorizontal ? view.contentX < view.contentWidth - parent.width + Tokens.padding.small : view.contentY < view.contentHeight - parent.height + Tokens.padding.small

            Behavior on opacity {
                Anim {}
            }
        }
    }

    ListView {
        id: view

        anchors.fill: parent
        orientation: root.isHorizontal ? ListView.Horizontal : ListView.Vertical
        spacing: Tokens.spacing.normal
        interactive: false

        currentIndex: model.values.findIndex(w => w.name === root.activeSpecial)
        onCurrentIndexChanged: currentIndex = Qt.binding(() => model.values.findIndex(w => w.name === root.activeSpecial))

        model: ScriptModel {
            values: Hypr.workspaces.values.filter(w => w.name.startsWith("special:") && (!GlobalConfig.bar.workspaces.perMonitorWorkspaces || w.monitor === root.monitor))
        }

        preferredHighlightBegin: 0
        preferredHighlightEnd: root.isHorizontal ? width : height
        highlightRangeMode: ListView.StrictlyEnforceRange

        highlightFollowsCurrentItem: false
        highlight: Item {
            x: root.isHorizontal ? view.currentItem?.x ?? 0 : 0
            y: root.isHorizontal ? 0 : view.currentItem?.y ?? 0
            width: root.isHorizontal ? ((view.currentItem as SpecialWsDelegate)?.size ?? 0) : parent.width
            height: root.isHorizontal ? parent.height : ((view.currentItem as SpecialWsDelegate)?.size ?? 0)

            Behavior on x { Anim {} }
            Behavior on y { Anim {} }
        }

        delegate: SpecialWsDelegate {}

        add: Transition {
            Anim {
                properties: "scale"
                from: 0
                to: 1
                easing: Tokens.anim.standardDecel
            }
        }

        remove: Transition {
            Anim {
                property: "scale"
                to: 0.5
                type: Anim.StandardSmall
            }
            Anim {
                property: "opacity"
                to: 0
                type: Anim.StandardSmall
            }
        }

        move: Transition {
            Anim {
                properties: "scale"
                to: 1
                easing: Tokens.anim.standardDecel
            }
            Anim {
                properties: "x,y"
            }
        }

        displaced: Transition {
            Anim {
                properties: "scale"
                to: 1
                easing: Tokens.anim.standardDecel
            }
            Anim {
                properties: "x,y"
            }
        }
    }

    Loader {
        asynchronous: true
        active: Config.bar.workspaces.activeIndicator
        anchors.fill: parent

        sourceComponent: Item {
            StyledClippingRect {
                id: indicator

                x: root.isHorizontal ? (view.currentItem?.x ?? 0) - view.contentX : 0
                y: root.isHorizontal ? 0 : (view.currentItem?.y ?? 0) - view.contentY
                width: root.isHorizontal ? ((view.currentItem as SpecialWsDelegate)?.size ?? 0) : parent.width
                height: root.isHorizontal ? parent.height : ((view.currentItem as SpecialWsDelegate)?.size ?? 0)

                color: Colours.palette.m3tertiary
                radius: Tokens.rounding.full

                Colouriser {
                    source: view
                    sourceColor: Colours.palette.m3onSurface
                    colorizationColor: Colours.palette.m3onTertiary

                    x: root.isHorizontal ? -indicator.x : 0
                    y: root.isHorizontal ? 0 : -indicator.y
                    implicitWidth: view.width
                    implicitHeight: view.height
                }

                Behavior on x {
                    Anim {
                        type: Anim.Emphasized
                    }
                }

                Behavior on y {
                    Anim {
                        type: Anim.Emphasized
                    }
                }

                Behavior on width {
                    Anim {
                        type: Anim.Emphasized
                    }
                }

                Behavior on height {
                    Anim {
                        type: Anim.Emphasized
                    }
                }
            }
        }
    }

    MouseArea {
        property real startPos

        anchors.fill: view

        drag.target: view.contentItem
        drag.axis: root.isHorizontal ? Drag.XAxis : Drag.YAxis
        drag.maximumX: 0
        drag.minimumX: Math.min(0, view.width - view.contentWidth - Tokens.padding.small)
        drag.maximumY: 0
        drag.minimumY: Math.min(0, view.height - view.contentHeight - Tokens.padding.small)

        onPressed: event => startPos = root.isHorizontal ? event.x : event.y

        onClicked: event => {
            if (Math.abs((root.isHorizontal ? event.x : event.y) - startPos) > drag.threshold)
                return;

            const ws = view.itemAt(event.x, event.y) as SpecialWsDelegate;
            if (ws?.modelData)
                Hypr.dispatch(`togglespecialworkspace ${ws.modelData.name.slice(8)}`);
            else
                Hypr.dispatch("togglespecialworkspace special");
        }
    }

    component SpecialWsDelegate: GridLayout {
        id: ws

        required property HyprlandWorkspace modelData
        readonly property int indicatorSize: Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2
        readonly property int size: root.isHorizontal ? indicatorSize + (hasWindows ? windows.implicitWidth + Tokens.padding.small : 0) : indicatorSize + (hasWindows ? windows.implicitHeight + Tokens.padding.small : 0)
        property int wsId
        property string icon
        property bool hasWindows

        x: root.isHorizontal ? 0 : (view.width - width) / 2
        width: root.isHorizontal ? size : view.width
        height: root.isHorizontal ? Tokens.sizes.bar.innerWidth : size
        columns: root.isHorizontal ? -1 : 1
        rows: root.isHorizontal ? 1 : -1
        rowSpacing: root.isHorizontal ? 0 : Tokens.padding.small
        columnSpacing: root.isHorizontal ? Tokens.padding.small : 0

        Component.onCompleted: {
            wsId = modelData.id;
            icon = Icons.getSpecialWsIcon(modelData.name);
            hasWindows = Config.bar.workspaces.showWindowsOnSpecialWorkspaces && modelData.lastIpcObject.windows > 0;
        }

        // Hacky thing cause modelData gets destroyed before the remove anim finishes
        Connections {
            function onIdChanged(): void {
                if (ws.modelData)
                    ws.wsId = ws.modelData.id;
            }

            function onNameChanged(): void {
                if (ws.modelData)
                    ws.icon = Icons.getSpecialWsIcon(ws.modelData.name);
            }

            function onLastIpcObjectChanged(): void {
                if (ws.modelData)
                    ws.hasWindows = root.Config.bar.workspaces.showWindowsOnSpecialWorkspaces && ws.modelData.lastIpcObject.windows > 0;
            }

            target: ws.modelData
        }

        Connections {
            function onShowWindowsOnSpecialWorkspacesChanged(): void {
                if (ws.modelData)
                    ws.hasWindows = root.Config.bar.workspaces.showWindowsOnSpecialWorkspaces && ws.modelData.lastIpcObject.windows > 0;
            }

            target: root.Config.bar.workspaces
        }

        Loader {
            id: label

            asynchronous: true

            Layout.alignment: root.isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter
            Layout.preferredWidth: root.isHorizontal ? ws.indicatorSize : Tokens.sizes.bar.innerWidth
            Layout.preferredHeight: root.isHorizontal ? Tokens.sizes.bar.innerWidth : ws.indicatorSize

            sourceComponent: ws.icon.length === 1 ? letterComp : iconComp

            Component {
                id: iconComp

                MaterialIcon {
                    fill: 1
                    text: ws.icon
                    verticalAlignment: Qt.AlignVCenter
                }
            }

            Component {
                id: letterComp

                StyledText {
                    text: ws.icon
                    verticalAlignment: Qt.AlignVCenter
                }
            }
        }

        Loader {
            id: windows

            asynchronous: true

            Layout.alignment: root.isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter
            Layout.fillWidth: root.isHorizontal
            Layout.fillHeight: !root.isHorizontal

            visible: active
            active: ws.hasWindows

            sourceComponent: GridLayout {
                columns: root.isHorizontal ? -1 : 1
                rows: root.isHorizontal ? 1 : -1
                rowSpacing: 0
                columnSpacing: 0

                Repeater {
                    model: ScriptModel {
                        values: {
                            const windows = Hypr.toplevels.values.filter(c => c.workspace?.id === ws.wsId);
                            const maxIcons = root.Config.bar.workspaces.maxWindowIcons;
                            return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                        }
                    }

                    MaterialIcon {
                        required property var modelData

                        grade: 0
                        text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }
            }

            Behavior on Layout.preferredHeight {
                Anim {}
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property int index
    required property int activeWsId
    required property var occupied
    required property int groupOffset
    required property bool isHorizontal

    readonly property bool isWorkspace: true
    readonly property int ws: groupOffset + index + 1
    readonly property bool isOccupied: occupied[ws] ?? false
    readonly property bool hasWindows: isOccupied && Config.bar.workspaces.showWindows
    readonly property int indicatorSize: Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2
    readonly property int gap: hasWindows ? Tokens.spacing.extraSmall : 0
    readonly property int size: isHorizontal ? implicitWidth : implicitHeight

    Layout.alignment: isHorizontal ? Qt.AlignVCenter : Qt.AlignHCenter
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight

    implicitWidth: isHorizontal ? indicatorSize + gap + (hasWindows ? windows.implicitWidth : 0) : Tokens.sizes.bar.innerWidth
    implicitHeight: isHorizontal ? Tokens.sizes.bar.innerWidth : indicatorSize + gap + (hasWindows ? windows.implicitHeight : 0)

    Loader {
        id: indicator

        x: root.isHorizontal ? 0 : (parent.width - width) / 2
        y: root.isHorizontal ? (parent.height - height) / 2 : 0
        width: root.indicatorSize
        height: root.indicatorSize
        active: true

        sourceComponent: workspaceLabel

        Component {
            id: workspaceLabel

            StyledText {
                // Always use the workspace number. Configured label glyphs and
                // workspace names were overriding the numeric labels per state.
                text: (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? root.ws - root.groupOffset : root.ws).toString()
                color: Config.bar.workspaces.occupiedBg || root.isOccupied || root.activeWsId === root.ws ? Colours.palette.m3onSurface : Colours.layer(Colours.palette.m3outlineVariant, 2)
                font.bold: root.activeWsId === root.ws
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.fill: parent
            }
        }
    }

    Loader {
        id: windows

        asynchronous: true
        active: root.hasWindows && Config.bar.workspaces.maxWindowIcons > 0
        visible: active
        x: root.isHorizontal ? root.indicatorSize + root.gap : (parent.width - width) / 2
        y: root.isHorizontal ? (parent.height - height) / 2 : root.indicatorSize + root.gap

        sourceComponent: GridLayout {
            columns: root.isHorizontal ? -1 : 1
            rows: root.isHorizontal ? 1 : -1
            rowSpacing: 0
            columnSpacing: 0

            Repeater {
                model: ScriptModel {
                    values: {
                        const windows = Hypr.toplevels.values.filter(c => c.workspace?.id === root.ws);
                        const maxIcons = root.Config.bar.workspaces.maxWindowIcons;
                        return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                    }
                }

                MaterialIcon {
                    required property var modelData

                    Layout.alignment: Qt.AlignCenter
                    grade: 0
                    text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property var widget
    required property ShellScreen screen

    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? Hypr.activeWsId
    readonly property var workspaces: Hypr.workspaces.values
        .filter(workspace => !String(workspace.name).startsWith("special:"))
        .sort((a, b) => a.id - b.id)
        .slice(0, 10)

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: "transparent"
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.normal

            RowLayout {
                Layout.fillWidth: true
                MaterialIcon { text: "view_quilt"; color: Colours.palette.m3primary }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("WORKSPACES")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.smaller
                        font.weight: 700
                        font.letterSpacing: 1
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: monitor?.name ?? qsTr("Current monitor")
                        color: Colours.palette.m3onSurface
                        font.pointSize: Tokens.font.size.large
                        font.bold: true
                        elide: Text.ElideRight
                    }
                }
                StyledRect {
                    implicitWidth: activeLabel.implicitWidth + Tokens.padding.normal * 2
                    implicitHeight: activeLabel.implicitHeight + Tokens.padding.small * 2
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3primaryContainer
                    StyledText {
                        id: activeLabel
                        anchors.centerIn: parent
                        text: qsTr("Workspace %1").arg(root.activeId)
                        color: Colours.palette.m3onPrimaryContainer
                        font.pointSize: Tokens.font.size.small
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Tokens.spacing.small

                Repeater {
                    model: root.workspaces
                    delegate: StyledRect {
                        required property var modelData
                        readonly property bool active: modelData.id === root.activeId
                        implicitWidth: Math.max(38, Math.min(84, label.implicitWidth + Tokens.padding.normal * 2))
                        implicitHeight: 34
                        radius: Tokens.rounding.normal
                        color: active ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh

                        StyledText {
                            id: label
                            anchors.centerIn: parent
                            width: parent.width - Tokens.padding.small * 2
                            text: String(parent.modelData.name || parent.modelData.id)
                            color: parent.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                            font.bold: parent.active
                            font.pointSize: Tokens.font.size.small
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                        }

                        StateLayer {
                            radius: parent.radius
                            onClicked: Hypr.dispatch(`workspace ${parent.modelData.id}`)
                        }
                    }
                }
            }
        }
    }
}

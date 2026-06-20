pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property Session session

    ColumnLayout {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.normal

        SettingsHeader {
            icon: "desktop_windows"
            title: qsTr("Display & Workspaces")
        }

        SectionHeader {
            Layout.topMargin: Tokens.spacing.large
            title: qsTr("Workspaces")
            description: qsTr("How workspaces behave across monitors")
        }

        SectionContainer {
            SplitButtonRow {
                label: qsTr("Mode")
                active: WorkspacePrefs.mode === "separate" ? separateItem : sharedItem
                menuItems: [
                    MenuItem {
                        id: separateItem

                        text: qsTr("Separate per monitor")
                        icon: "splitscreen"
                        onClicked: WorkspacePrefs.setMode("separate")
                    },
                    MenuItem {
                        id: sharedItem

                        text: qsTr("Shared")
                        icon: "join_full"
                        onClicked: WorkspacePrefs.setMode("shared")
                    }
                ]
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            wrapMode: Text.Wrap
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
            text: qsTr("Separate: each monitor keeps its own workspaces and Super+1..0 follows the focused monitor. Shared: workspaces float across monitors (Hyprland default).\n\nMonitor arrangement (position / mirror / extend / single) is coming to this pane next.")
        }
    }
}

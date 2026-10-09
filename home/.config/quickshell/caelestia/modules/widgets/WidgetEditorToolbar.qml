pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    required property string screenName
    required property string screenSize
    property bool gridSnap: false
    property bool focusMode: false

    signal layoutRequested(string mode)
    signal clearRequested()
    signal closeRequested()
    signal focusModeRequested()

    implicitHeight: 58
    radius: Tokens.rounding.large
    color: Colours.palette.m3surfaceContainer
    clip: true

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Tokens.padding.large
        anchors.rightMargin: Tokens.padding.large
        spacing: Tokens.spacing.small

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Arrange desktop widgets")
            color: Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.large
            font.bold: true
            elide: Text.ElideRight
        }

        StyledText {
            text: root.screenName
            color: Colours.palette.m3onSurfaceVariant
            elide: Text.ElideRight
        }

        StyledText {
            text: `${root.screenSize} · 1:1`
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
        }

        IconButton {
            id: layoutButton
            icon: "auto_awesome_motion"
            onClicked: layoutMenu.expanded = !layoutMenu.expanded
        }

        IconButton {
            icon: root.gridSnap ? "grid_on" : "grid_off"
            onClicked: root.gridSnap = !root.gridSnap
        }

        IconButton {
            icon: root.focusMode ? "fullscreen_exit" : "fullscreen"
            onClicked: root.focusModeRequested()
        }

        IconButton { icon: "delete_sweep"; onClicked: root.clearRequested() }
        IconButton { icon: "close"; onClicked: root.closeRequested() }
    }

    Menu {
        id: layoutMenu
        z: 2
        attachTo: layoutButton
        items: [
            MenuItem { text: qsTr("Tidy grid · fit widgets"); onClicked: root.layoutRequested("grid") },
            MenuItem { text: qsTr("Arrange in a row"); onClicked: root.layoutRequested("row") },
            MenuItem { text: qsTr("Arrange in a column"); onClicked: root.layoutRequested("column") },
            MenuItem { text: qsTr("Align left"); onClicked: root.layoutRequested("alignLeft") },
            MenuItem { text: qsTr("Center horizontally"); onClicked: root.layoutRequested("alignCenter") },
            MenuItem { text: qsTr("Align right"); onClicked: root.layoutRequested("alignRight") },
            MenuItem { text: qsTr("Align top"); onClicked: root.layoutRequested("alignTop") },
            MenuItem { text: qsTr("Center vertically"); onClicked: root.layoutRequested("alignMiddle") },
            MenuItem { text: qsTr("Align bottom"); onClicked: root.layoutRequested("alignBottom") },
            MenuItem { text: qsTr("Distribute horizontally"); onClicked: root.layoutRequested("distributeHorizontal") },
            MenuItem { text: qsTr("Distribute vertically"); onClicked: root.layoutRequested("distributeVertical") },
            MenuItem { text: qsTr("Select all widgets"); onClicked: root.layoutRequested("selectAll") },
            MenuItem { text: qsTr("Clear selection"); onClicked: root.layoutRequested("clearSelection") }
        ]
    }
}

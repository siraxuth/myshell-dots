import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

// Per-monitor toggle for the hover/drag dashboard. One switch per connected screen;
// turning a monitor off stops the dashboard sliding down when the cursor (or pen) nears
// its top edge there. The explicit keybind still works.
SectionContainer {
    id: root

    required property var rootItem

    Layout.fillWidth: true
    alignTop: true

    StyledText {
        text: qsTr("Show dashboard on monitors")
        font.pointSize: Tokens.font.size.normal
    }

    StyledText {
        Layout.fillWidth: true
        text: qsTr("Turn a monitor off to stop the dashboard appearing on hover there — handy while drawing with a pen.")
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: Quickshell.screens

        SwitchRow {
            required property var modelData

            label: modelData.name
            checked: DashboardPrefs.isEnabledFor(modelData.name)
            onToggled: on => DashboardPrefs.setEnabledFor(modelData.name, on)
        }
    }
}

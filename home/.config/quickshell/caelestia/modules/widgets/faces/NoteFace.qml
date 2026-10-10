pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property var widget
    required property ShellScreen screen

    function saveDraft(): void {
        if (!note.dirty)
            return;
        note.dirty = false;
        WidgetsPrefs.updateWidgetProperty(root.screen.name, String(root.widget.wId), "noteText", note.text);
    }

    StyledRect {
        anchors.fill: parent
        radius: Tokens.rounding.large
        color: "transparent"
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                MaterialIcon { text: "sticky_note_2"; color: Colours.palette.m3tertiary }
                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("QUICK NOTE")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.smaller
                    font.weight: 700
                    font.letterSpacing: 1
                    elide: Text.ElideRight
                }
            }

            TextArea {
                id: note
                Layout.fillWidth: true
                Layout.fillHeight: true
                property bool dirty: false
                text: String(root.widget.wProps?.noteText ?? "")
                placeholderText: qsTr("Write a reminder…")
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                color: Colours.palette.m3onSurface
                placeholderTextColor: Colours.palette.m3outline
                font.family: Tokens.font.family.sans
                font.pointSize: Tokens.font.size.normal
                background: null
                persistentSelection: true
                onTextChanged: if (activeFocus) dirty = true
                onActiveFocusChanged: if (!activeFocus) root.saveDraft()
            }
        }
    }
}

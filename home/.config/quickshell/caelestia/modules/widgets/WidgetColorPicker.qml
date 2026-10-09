pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    required property string title
    required property string value
    required property color fallback
    signal colorSelected(string value)

    readonly property var palette: [
        { value: "", color: Colours.palette.m3surfaceContainer, label: qsTr("Theme") },
        { value: "primary", color: Colours.palette.m3primaryContainer, label: qsTr("Primary") },
        { value: "secondary", color: Colours.palette.m3secondaryContainer, label: qsTr("Secondary") },
        { value: "tertiary", color: Colours.palette.m3tertiaryContainer, label: qsTr("Tertiary") },
        { value: "#ffffff", color: "#ffffff", label: qsTr("White") },
        { value: "#b8c0cc", color: "#b8c0cc", label: qsTr("Silver") },
        { value: "#667085", color: "#667085", label: qsTr("Slate") },
        { value: "#17191f", color: "#17191f", label: qsTr("Ink") },
        { value: "#ff6b6b", color: "#ff6b6b", label: qsTr("Red") },
        { value: "#ff9f43", color: "#ff9f43", label: qsTr("Orange") },
        { value: "#ffd166", color: "#ffd166", label: qsTr("Yellow") },
        { value: "#65c18c", color: "#65c18c", label: qsTr("Green") },
        { value: "#2dd4bf", color: "#2dd4bf", label: qsTr("Teal") },
        { value: "#55a7ff", color: "#55a7ff", label: qsTr("Blue") },
        { value: "#8b7bff", color: "#8b7bff", label: qsTr("Indigo") },
        { value: "#c084fc", color: "#c084fc", label: qsTr("Purple") },
        { value: "#f472b6", color: "#f472b6", label: qsTr("Pink") }
    ]

    radius: Tokens.rounding.normal
    color: Colours.palette.m3surface
    border.width: 1
    border.color: Colours.palette.m3outlineVariant
    implicitHeight: 28 + Tokens.padding.normal * 2

    function resolvedColor(raw: string): color {
        const key = String(raw ?? "").trim().toLowerCase();
        if (key === "primary") return Colours.palette.m3primaryContainer;
        if (key === "secondary") return Colours.palette.m3secondaryContainer;
        if (key === "tertiary") return Colours.palette.m3tertiaryContainer;
        if (key === "surface" || !key) return Colours.palette.m3surfaceContainer;
        return /^#[0-9a-f]{6}$/i.test(key) ? Qt.color(key) : fallback;
    }

    function hexColor(raw: string): string {
        const c = resolvedColor(raw);
        const hex = channel => Math.round(channel * 255).toString(16).padStart(2, "0");
        return `#${hex(c.r)}${hex(c.g)}${hex(c.b)}`;
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.normal
        StyledText { Layout.fillWidth: true; text: root.title; color: Colours.palette.m3onSurface; font.bold: true }
        Rectangle {
            width: 28; height: 28
            radius: Tokens.rounding.small
            color: root.resolvedColor(root.value)
            border.width: 1
            border.color: Colours.palette.m3outlineVariant
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: pickerPopup.open()
            }
        }
        TextButton {
            text: qsTr("Choose")
            onClicked: pickerPopup.open()
        }
    }

    Popup {
        id: pickerPopup
        parent: Overlay.overlay
        z: 9999
        width: 300
        padding: Tokens.padding.normal
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        function placeNearPicker(): void {
            if (!parent) return;
            const point = root.mapToItem(parent, 0, 0);
            const gap = Tokens.spacing.small;
            const margin = Tokens.padding.normal;
            x = Math.max(margin, Math.min(parent.width - width - margin, point.x + root.width - width));
            const above = point.y - height - gap;
            y = above >= margin ? above : Math.min(parent.height - height - margin, point.y + root.height + gap);
        }

        onOpened: Qt.callLater(placeNearPicker)

        background: StyledRect {
            color: Colours.palette.m3surfaceContainerHigh
            radius: Tokens.rounding.large
            border.width: 1
            border.color: Colours.palette.m3outlineVariant
        }

        contentItem: ColumnLayout {
            spacing: Tokens.spacing.normal

            RowLayout {
                Layout.fillWidth: true
                StyledText { Layout.fillWidth: true; text: root.title; color: Colours.palette.m3onSurface; font.bold: true }
                StyledText { text: root.hexColor(root.value); color: Colours.palette.m3onSurfaceVariant }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 8
                Repeater {
                    model: root.palette
                    delegate: Rectangle {
                        required property var modelData
                        width: 34; height: 34
                        radius: Tokens.rounding.small
                        color: modelData.color
                        border.width: root.value === modelData.value ? 3 : 1
                        border.color: root.value === modelData.value ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.colorSelected(parent.modelData.value);
                                pickerPopup.close();
                            }
                        }
                        ToolTip.visible: hoverHandler.hovered
                        ToolTip.text: modelData.label
                        HoverHandler { id: hoverHandler }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                StyledText { text: qsTr("Custom HEX"); color: Colours.palette.m3onSurfaceVariant }
                StyledInputField {
                    id: hexInput
                    Layout.fillWidth: true
                    text: root.hexColor(root.value)
                    onTextEdited: text => {
                        const normalized = text.trim().replace(/^#/, "");
                        if (/^[0-9a-f]{6}$/i.test(normalized)) root.colorSelected(`#${normalized.toLowerCase()}`);
                    }
                }
            }
        }
    }
}

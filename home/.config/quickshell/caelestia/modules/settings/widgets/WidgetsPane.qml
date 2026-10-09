pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property Session session
    property string selectedScreenName: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : ""

    readonly property var widgets: WidgetsPrefs.layoutFor(selectedScreenName)

    function addWidget(type: string): void {
        if (!WidgetsPrefs.isReady(selectedScreenName))
            return;
        const screen = Quickshell.screens.find(item => item.name === selectedScreenName) ?? Quickshell.screens[0];
        const id = WidgetsPrefs.addWidget(selectedScreenName, type, screen?.width ?? 1280, screen?.height ?? 720);
        if (id)
            WidgetEditorController.open(selectedScreenName, id);
    }

    PaneFrame {
        anchors.fill: parent

        Flickable {
            anchors.fill: parent
            contentHeight: content.implicitHeight + Tokens.padding.large * 2
            clip: true

            ColumnLayout {
                id: content
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: Tokens.spacing.normal

                SettingsHeader {
                    icon: "widgets"
                    title: qsTr("Desktop Widgets")
                }

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                    text: qsTr("Choose a screen, manage its widgets, then arrange them directly on the desktop.")
                }

                SectionHeader {
                    Layout.topMargin: Tokens.spacing.small
                    title: qsTr("Display")
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small
                    Repeater {
                        model: Quickshell.screens
                        Pill {
                            required property ShellScreen modelData
                            label: modelData.name
                            selected: modelData.name === root.selectedScreenName
                            onClicked: {
                                root.selectedScreenName = modelData.name;
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.small
                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Widgets on %1").arg(root.selectedScreenName || qsTr("this screen"))
                        color: Colours.palette.m3onSurface
                        font.bold: true
                    }
                    TextButton {
                        text: qsTr("Open canvas editor")
                        enabled: WidgetsPrefs.isReady(root.selectedScreenName)
                        onClicked: WidgetEditorController.open(root.selectedScreenName, "")
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: !WidgetsPrefs.isReady(root.selectedScreenName) || root.widgets.length === 0
                    text: WidgetsPrefs.isReady(root.selectedScreenName) ? qsTr("No widgets on this screen yet. Add one below.") : qsTr("Loading this screen’s widgets…")
                    color: Colours.palette.m3onSurfaceVariant
                }

                Repeater {
                    model: root.widgets
                    WidgetRow {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        widget: modelData
                        screenName: root.selectedScreenName
                        indexInList: index
                        onEditRequested: WidgetEditorController.open(root.selectedScreenName, widget.wId)
                    }
                }

                SectionHeader {
                    Layout.topMargin: Tokens.spacing.large
                    title: qsTr("Add a widget")
                    description: qsTr("Select a widget to add it, then place it in the canvas editor.")
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small
                    Repeater {
                        model: WidgetRegistry.typeList()
                        AddWidgetButton {
                            required property var modelData
                            enabled: WidgetsPrefs.isReady(root.selectedScreenName)
                            icon: modelData.icon
                            label: modelData.name
                            onClicked: root.addWidget(modelData.id)
                        }
                    }
                }
            }
        }
    }

    component Pill: StyledRect {
        id: pill
        property string label
        property bool selected: false
        signal clicked
        implicitWidth: pillText.implicitWidth + Tokens.padding.large * 2
        implicitHeight: pillText.implicitHeight + Tokens.padding.normal * 2
        radius: Tokens.rounding.full
        color: selected ? Colours.palette.m3primaryContainer : Colours.layer(Colours.palette.m3surfaceContainer, 1)
        StyledText {
            id: pillText
            anchors.centerIn: parent
            text: pill.label
            color: pill.selected ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.small
        }
        StateLayer {
            radius: parent.radius
            onClicked: pill.clicked()
        }
    }

    component WidgetRow: StyledRect {
        id: row
        required property var widget
        required property string screenName
        required property int indexInList
        signal editRequested

        implicitHeight: rowContent.implicitHeight + Tokens.padding.normal * 2
        radius: Tokens.rounding.normal
        color: Colours.layer(Colours.palette.m3surfaceContainer, 1)

        ColumnLayout {
            id: rowContent
            anchors.fill: parent
            anchors.margins: Tokens.padding.normal
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                MaterialIcon {
                    text: WidgetRegistry.get(row.widget.wType).icon
                    color: Colours.palette.m3primary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: WidgetRegistry.get(row.widget.wType).name
                    color: Colours.palette.m3onSurface
                    font.bold: true
                }
                IconButton {
                    icon: "arrow_upward"
                    type: IconButton.Text
                    disabled: row.indexInList >= WidgetsPrefs.layoutFor(row.screenName).length - 1
                    onClicked: WidgetsPrefs.moveWidget(row.screenName, row.widget.wId, 1)
                }
                IconButton {
                    icon: "arrow_downward"
                    type: IconButton.Text
                    disabled: row.indexInList <= 0
                    onClicked: WidgetsPrefs.moveWidget(row.screenName, row.widget.wId, -1)
                }
                IconButton {
                    icon: row.widget.enabled === false ? "visibility_off" : "visibility"
                    type: IconButton.Text
                    onClicked: WidgetsPrefs.updateWidget(row.screenName, row.widget.wId, "enabled", row.widget.enabled === false)
                }
                IconButton {
                    icon: "edit"
                    type: IconButton.Text
                    onClicked: row.editRequested()
                }
                IconButton {
                    icon: "delete"
                    type: IconButton.Text
                    onClicked: WidgetsPrefs.removeWidget(row.screenName, row.widget.wId)
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small / 2
                Repeater {
                    model: WidgetRegistry.get(row.widget.wType).variants
                    StyledRect {
                        required property string modelData
                        implicitWidth: variantLabel.implicitWidth + Tokens.padding.normal * 2
                        implicitHeight: variantLabel.implicitHeight + Tokens.padding.small * 2
                        radius: Tokens.rounding.full
                        color: modelData === row.widget.wVariant ? Colours.palette.m3secondaryContainer : Colours.palette.m3surface
                        StyledText {
                            id: variantLabel
                            anchors.centerIn: parent
                            text: parent.modelData
                            color: parent.modelData === row.widget.wVariant ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            font.pointSize: Tokens.font.size.small
                        }
                        StateLayer {
                            radius: parent.radius
                            onClicked: WidgetsPrefs.setVariant(row.screenName, row.widget.wId, parent.modelData)
                        }
                    }
                }
            }
        }
    }

    component AddWidgetButton: StyledRect {
        id: addButton
        property string icon
        property string label
        signal clicked
        implicitWidth: addText.implicitWidth + Tokens.padding.large * 2 + addIcon.implicitWidth + Tokens.spacing.small
        implicitHeight: Math.max(addText.implicitHeight, addIcon.implicitHeight) + Tokens.padding.normal * 2
        radius: Tokens.rounding.full
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        RowLayout {
            anchors.centerIn: parent
            spacing: Tokens.spacing.small
            MaterialIcon { id: addIcon; text: addButton.icon; color: Colours.palette.m3primary }
            StyledText { id: addText; text: addButton.label; color: Colours.palette.m3onSurface; font.pointSize: Tokens.font.size.small }
        }
        StateLayer {
            radius: parent.radius
            disabled: !addButton.enabled
            onClicked: addButton.clicked()
        }
    }
}

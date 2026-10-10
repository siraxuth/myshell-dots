pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.modules.widgets
import ".."
import "../components"

Item {
    id: root
    required property Session session
    property string selectedScreenName: session.root.screen?.name ?? Quickshell.screens[0]?.name ?? ""
    readonly property ShellScreen selectedScreen: Quickshell.screens.find(s => s.name === selectedScreenName) ?? null
    readonly property bool paneActive: session.active === "widgets" || session.active === "Widgets" || session.activeIndex === PaneRegistry.getIndexById("widgets")
    function resolveScreen(): void {
        if (!selectedScreen)
            selectedScreenName = Quickshell.screens[0]?.name ?? "";
    }
    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            root.resolveScreen();
        }
    }

    PaneFrame {
        anchors.fill: parent
        Flickable {
            id: page
            SettingsScrollHandler {
                flickable: page
            }

            anchors.fill: parent
            contentWidth: width
            contentHeight: content.height
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            ColumnLayout {
                id: content
                width: page.width
                height: Math.max(page.height, implicitHeight)
                spacing: 14
                SettingsHeader {
                    icon: "widgets"
                    title: qsTr("Desktop canvas")
                }
                TextButton {
                    Layout.fillWidth: true
                    text: qsTr("Arrange desktop · Full screen")
                    enabled: !!root.selectedScreen && WidgetsPrefs.isReady(root.selectedScreenName)
                    onClicked: WidgetEditorController.open(root.selectedScreenName, "")
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: Quickshell.screens
                        TextButton {
                            required property ShellScreen modelData
                            text: modelData.name
                            type: modelData.name === root.selectedScreenName ? TextButton.Filled : TextButton.Tonal
                            onClicked: root.selectedScreenName = modelData.name
                        }
                    }
                }
                WidgetWorkspace {
                    id: workspace
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: width >= 900 ? 500 : 620
                    screen: root.selectedScreen
                    running: root.paneActive && !WidgetEditorController.active
                    onFullscreenRequested: WidgetEditorController.open(root.selectedScreenName, selectedIds[selectedIds.length - 1] ?? "")
                }
            }
        }
    }
}

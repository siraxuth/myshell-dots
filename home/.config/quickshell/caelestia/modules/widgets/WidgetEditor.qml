pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

Scope {
    Loader {
        active: WidgetEditorController.active && Quickshell.screens.some(s => s.name === WidgetEditorController.screenName)
        sourceComponent: PanelWindow {
            id: window
            readonly property ShellScreen targetScreen: Quickshell.screens.find(s => s.name === WidgetEditorController.screenName) ?? null
            screen: targetScreen
            color: Colours.palette.m3surface
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            focusable: true
            WlrLayershell.namespace: "caelestia-widget-editor"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WidgetWorkspace {
                anchors.fill: parent
                screen: window.targetScreen
                fullscreen: true
                selectedIds: WidgetEditorController.selectedWidgetId ? [WidgetEditorController.selectedWidgetId] : []
                onCloseRequested: WidgetEditorController.close()
            }
        }
    }
    Connections {
        target: Quickshell
        function onScreensChanged(): void {
            if (!Quickshell.screens.some(s => s.name === WidgetEditorController.screenName))
                WidgetEditorController.close();
        }
    }
}

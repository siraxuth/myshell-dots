pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    property string screenName: ""
    property string selectedWidgetId: ""

    function open(screen: string, widgetId: string): void {
        screenName = screen || (Quickshell.screens.length ? Quickshell.screens[0].name : "");
        selectedWidgetId = widgetId || "";
        active = true;
    }

    IpcHandler {
        target: "widgetEditor"
        function open(screenName: string): void {
            root.open(screenName, "");
        }
        function close(): void {
            root.close();
        }
    }

    function close(): void {
        active = false;
        selectedWidgetId = "";
    }
}

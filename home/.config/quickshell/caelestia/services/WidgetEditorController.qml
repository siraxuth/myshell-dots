pragma Singleton

import QtQuick
import Quickshell

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

    function close(): void {
        active = false;
        selectedWidgetId = "";
    }
}

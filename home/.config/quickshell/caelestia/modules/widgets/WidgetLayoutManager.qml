pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Variants {
    model: Quickshell.screens

    WidgetLayoutStore {
        required property ShellScreen modelData
        screen: modelData
    }
}

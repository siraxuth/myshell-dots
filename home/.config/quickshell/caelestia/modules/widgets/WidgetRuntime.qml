pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

Item {
    id: root

    required property ShellScreen screen
    anchors.fill: parent

    Repeater {
        model: WidgetsPrefs.layoutFor(root.screen.name)

        Item {
            id: widgetHost

            required property var modelData
            required property int index

            readonly property var widgetPosition: WidgetRegistry.positionFor(modelData, root.width, root.height)
            readonly property var widgetSize: WidgetRegistry.sizeFor(modelData, root.width, root.height)
            x: widgetPosition.x
            y: widgetPosition.y
            width: modelData.wProps?.stretchWidth || modelData.wStretchWidth || modelData.stretchWidth ? root.width : widgetSize.width
            height: modelData.wProps?.stretchHeight || modelData.wStretchHeight || modelData.stretchHeight ? root.height : widgetSize.height
            visible: modelData.enabled !== false
            z: index

            Widget {
                anchors.fill: parent
                widget: widgetHost.modelData
                screen: root.screen
            }
        }
    }
}

pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property list<QtObject> panes: [
        QtObject {
            readonly property string id: "network"
            readonly property string label: "network"
            readonly property string description: qsTr("Wi-Fi and VPN")
            readonly property string icon: "router"
            readonly property string component: "network/NetworkingPane.qml"
        },
        QtObject {
            readonly property string id: "widgets"
            readonly property string label: "widgets"
            readonly property string description: qsTr("Manage desktop widgets")
            readonly property string icon: "widgets"
            readonly property string component: "widgets/WidgetsPane.qml"
        },
        QtObject {
            readonly property string id: "bluetooth"
            readonly property string label: "bluetooth"
            readonly property string description: qsTr("Bluetooth devices")
            readonly property string icon: "settings_bluetooth"
            readonly property string component: "bluetooth/BtPane.qml"
        },
        QtObject {
            readonly property string id: "audio"
            readonly property string label: "audio"
            readonly property string description: qsTr("Sound devices")
            readonly property string icon: "volume_up"
            readonly property string component: "audio/AudioPane.qml"
        },
        QtObject {
            readonly property string id: "terminal"
            readonly property string label: "terminal"
            readonly property string description: qsTr("Foot blur and opacity")
            readonly property string icon: "terminal"
            readonly property string component: "terminal/TerminalPane.qml"
        },
        QtObject {
            readonly property string id: "appearance"
            readonly property string label: "appearance"
            readonly property string description: qsTr("Themes and colors")
            readonly property string icon: "palette"
            readonly property string component: "appearance/AppearancePane.qml"
        },
        QtObject {
            readonly property string id: "taskbar"
            readonly property string label: "taskbar"
            readonly property string description: qsTr("Bar settings")
            readonly property string icon: "task_alt"
            readonly property string component: "taskbar/TaskbarPane.qml"
        },
        QtObject {
            readonly property string id: "notifications"
            readonly property string label: "notifications"
            readonly property string description: qsTr("Alerts")
            readonly property string icon: "notifications"
            readonly property string component: "notifications/NotificationsPane.qml"
        },
        QtObject {
            readonly property string id: "launcher"
            readonly property string label: "launcher"
            readonly property string description: qsTr("Apps and search")
            readonly property string icon: "apps"
            readonly property string component: "launcher/LauncherPane.qml"
        },
        QtObject {
            readonly property string id: "dashboard"
            readonly property string label: "dashboard"
            readonly property string description: qsTr("Dashboard widgets")
            readonly property string icon: "dashboard"
            readonly property string component: "dashboard/DashboardPane.qml"
        },
        QtObject {
            readonly property string id: "display"
            readonly property string label: "display"
            readonly property string description: qsTr("Displays")
            readonly property string icon: "desktop_windows"
            readonly property string component: "display/DisplayPane.qml"
        },
        QtObject {
            readonly property string id: "input"
            readonly property string label: "input"
            readonly property string description: qsTr("Mouse and pointer speed")
            readonly property string icon: "mouse"
            readonly property string component: "input/InputPane.qml"
        },
        QtObject {
            readonly property string id: "events"
            readonly property string label: "events"
            readonly property string description: qsTr("Calendar and reminders")
            readonly property string icon: "event"
            readonly property string component: "events/EventsPane.qml"
        },
        QtObject {
            readonly property string id: "storage"
            readonly property string label: "storage"
            readonly property string description: qsTr("Disk usage and cleanup")
            readonly property string icon: "hard_drive"
            readonly property string component: "storage/StoragePane.qml"
        },
        QtObject {
            readonly property string id: "power"
            readonly property string label: "power"
            readonly property string description: qsTr("Battery and idle")
            readonly property string icon: "bolt"
            readonly property string component: "power/PowerPane.qml"
        }
    ]

    readonly property list<QtObject> categories: [
        QtObject {
            readonly property string name: qsTr("Connectivity")
            readonly property list<string> paneIds: ["network", "bluetooth"]
        },
        QtObject {
            readonly property string name: qsTr("Personalization")
            readonly property list<string> paneIds: ["widgets", "appearance", "taskbar", "launcher", "dashboard"]
        },
        QtObject {
            readonly property string name: qsTr("System")
            readonly property list<string> paneIds: ["audio", "terminal", "display", "input", "events", "storage", "notifications", "power"]
        }
    ]

    readonly property int count: panes.length

    readonly property var labels: {
        const result = [];
        for (let i = 0; i < panes.length; i++) {
            result.push(panes[i].label);
        }
        return result;
    }

    function getByIndex(index: int): var {
        if (index >= 0 && index < panes.length) {
            return panes[index];
        }
        return null;
    }

    function getIndexByLabel(label: string): int {
        for (let i = 0; i < panes.length; i++) {
            if (panes[i].label === label) {
                return i;
            }
        }
        return -1;
    }

    function getByLabel(label: string): var {
        const index = getIndexByLabel(label);
        return getByIndex(index);
    }

    function getById(id: string): var {
        for (let i = 0; i < panes.length; i++) {
            if (panes[i].id === id) {
                return panes[i];
            }
        }
        return null;
    }

    function getIndexById(id: string): int {
        for (let i = 0; i < panes.length; i++) {
            if (panes[i].id === id) {
                return i;
            }
        }
        return -1;
    }
}

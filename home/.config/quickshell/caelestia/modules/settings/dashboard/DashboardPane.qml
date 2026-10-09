pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

Item {
    id: root

    required property Session session

    // General Settings
    property bool enabled: Config.dashboard.enabled ?? true
    property bool showOnHover: Config.dashboard.showOnHover ?? true
    property int mediaUpdateInterval: Math.max(1000, GlobalConfig.dashboard.mediaUpdateInterval ?? 1000)
    property int resourceUpdateInterval: Math.max(5000, GlobalConfig.dashboard.resourceUpdateInterval ?? 10000)
    property int dragThreshold: Config.dashboard.dragThreshold ?? 50

    // Dashboard Tabs
    property bool showDashboard: Config.dashboard.showDashboard ?? true
    property bool showMedia: Config.dashboard.showMedia ?? true
    property bool showPerformance: Config.dashboard.showPerformance ?? true
    property bool showWeather: Config.dashboard.showWeather ?? true

    // Performance Resources
    property bool showBattery: Config.dashboard.performance.showBattery ?? false
    property bool showGpu: Config.dashboard.performance.showGpu ?? true
    property bool showCpu: Config.dashboard.performance.showCpu ?? true
    property bool showMemory: Config.dashboard.performance.showMemory ?? true
    property bool showStorage: Config.dashboard.performance.showStorage ?? true
    property bool showNetwork: Config.dashboard.performance.showNetwork ?? true

    function saveConfig() {
        GlobalConfig.dashboard.enabled = root.enabled;
        GlobalConfig.dashboard.showOnHover = root.showOnHover;
        GlobalConfig.dashboard.mediaUpdateInterval = root.mediaUpdateInterval;
        GlobalConfig.dashboard.resourceUpdateInterval = root.resourceUpdateInterval;
        GlobalConfig.dashboard.dragThreshold = root.dragThreshold;
        GlobalConfig.dashboard.showDashboard = root.showDashboard;
        GlobalConfig.dashboard.showMedia = root.showMedia;
        GlobalConfig.dashboard.showPerformance = root.showPerformance;
        GlobalConfig.dashboard.showWeather = root.showWeather;
        GlobalConfig.dashboard.performance.showBattery = root.showBattery;
        GlobalConfig.dashboard.performance.showGpu = root.showGpu;
        GlobalConfig.dashboard.performance.showCpu = root.showCpu;
        GlobalConfig.dashboard.performance.showMemory = root.showMemory;
        GlobalConfig.dashboard.performance.showStorage = root.showStorage;
        GlobalConfig.dashboard.performance.showNetwork = root.showNetwork;
        // Note: sizes properties are readonly and cannot be modified
    }

    anchors.fill: parent

    PaneFrame {
        anchors.fill: parent
        Loader {
            id: dashboardLoader

            anchors.fill: parent
            asynchronous: true
            sourceComponent: dashboardContentComponent
        }
    }

    Component {
        id: dashboardContentComponent

        StyledFlickable {
            id: dashboardFlickable

            flickableDirection: Flickable.VerticalFlick
            contentHeight: dashboardLayout.height

            StyledScrollBar.vertical: StyledScrollBar {
                flickable: dashboardFlickable
            }

            ColumnLayout {
                id: dashboardLayout

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                spacing: Tokens.spacing.normal

                RowLayout {
                    spacing: Tokens.spacing.smaller

                    StyledText {
                        text: qsTr("Dashboard")
                        font.pointSize: Tokens.font.size.large
                        font.weight: 500
                    }
                }

                // General Settings Section
                GeneralSection {
                    rootItem: root
                }

                // Per-monitor visibility
                MonitorsSection {
                    rootItem: root
                }

                // Performance Resources Section
                PerformanceSection {
                    rootItem: root
                }
            }
        }
    }
}

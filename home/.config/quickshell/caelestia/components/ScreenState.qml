import QtQuick
import Quickshell

PersistentProperties {
    id: root

    required property ShellScreen modelData
    required property DrawerVisibilities visibilities
    required property DashboardState dashboardState

    property bool bar
    property bool osd
    property bool session
    property bool launcher
    property bool dashboard
    property bool capture
    property bool liveWallpaper
    property bool utilities
    property bool sidebar

    property int dashboardTab
    property date dashboardDate: new Date()

    property bool syncing: false

    function readVisibilities(): void {
        syncing = true;
        bar = visibilities.bar;
        osd = visibilities.osd;
        session = visibilities.session;
        launcher = visibilities.launcher;
        dashboard = visibilities.dashboard;
        capture = visibilities.capture;
        liveWallpaper = visibilities.liveWallpaper;
        utilities = visibilities.utilities;
        sidebar = visibilities.sidebar;
        syncing = false;
    }

    function writeVisibilities(): void {
        if (syncing || !visibilities)
            return;
        syncing = true;
        if (visibilities.bar !== bar) visibilities.bar = bar;
        if (visibilities.osd !== osd) visibilities.osd = osd;
        if (visibilities.session !== session) visibilities.session = session;
        if (visibilities.launcher !== launcher) visibilities.launcher = launcher;
        if (visibilities.dashboard !== dashboard) visibilities.dashboard = dashboard;
        if (visibilities.capture !== capture) visibilities.capture = capture;
        if (visibilities.liveWallpaper !== liveWallpaper) visibilities.liveWallpaper = liveWallpaper;
        if (visibilities.utilities !== utilities) visibilities.utilities = utilities;
        if (visibilities.sidebar !== sidebar) visibilities.sidebar = sidebar;
        syncing = false;
    }

    function readDashboardState(): void {
        dashboardTab = dashboardState.currentTab;
        dashboardDate = dashboardState.currentDate;
    }

    function writeDashboardState(): void {
        if (dashboardState.currentTab !== dashboardTab)
            dashboardState.currentTab = dashboardTab;
        if (dashboardState.currentDate.getTime() !== dashboardDate.getTime())
            dashboardState.currentDate = dashboardDate;
    }

    Component.onCompleted: {
        readVisibilities();
        readDashboardState();
    }

    onBarChanged: writeVisibilities()
    onOsdChanged: writeVisibilities()
    onSessionChanged: writeVisibilities()
    onLauncherChanged: writeVisibilities()
    onDashboardChanged: writeVisibilities()
    onCaptureChanged: writeVisibilities()
    onLiveWallpaperChanged: writeVisibilities()
    onUtilitiesChanged: writeVisibilities()
    onSidebarChanged: writeVisibilities()
    onDashboardTabChanged: writeDashboardState()
    onDashboardDateChanged: writeDashboardState()

    property Connections visibilityConnections: Connections {
        target: root.visibilities

        function onBarChanged(): void { root.bar = root.visibilities.bar; }
        function onOsdChanged(): void { root.osd = root.visibilities.osd; }
        function onSessionChanged(): void { root.session = root.visibilities.session; }
        function onLauncherChanged(): void { root.launcher = root.visibilities.launcher; }
        function onDashboardChanged(): void { root.dashboard = root.visibilities.dashboard; }
        function onCaptureChanged(): void { root.capture = root.visibilities.capture; }
        function onLiveWallpaperChanged(): void { root.liveWallpaper = root.visibilities.liveWallpaper; }
        function onUtilitiesChanged(): void { root.utilities = root.visibilities.utilities; }
        function onSidebarChanged(): void { root.sidebar = root.visibilities.sidebar; }
    }

    property Connections dashboardConnections: Connections {
        target: root.dashboardState

        function onCurrentTabChanged(): void { root.dashboardTab = root.dashboardState.currentTab; }
        function onCurrentDateChanged(): void { root.dashboardDate = root.dashboardState.currentDate; }
    }
}

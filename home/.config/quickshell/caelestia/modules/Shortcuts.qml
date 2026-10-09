import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import qs.components.misc
import qs.services
import qs.modules.settings

Scope {
    id: root

    property bool launcherInterrupted
    property var pendingLiveWallpaperVisibility: null
    readonly property bool hasFullscreen: Hypr.focusedWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false

    Component.onCompleted: Wallpapers.refreshWallpapers()

    Timer {
        id: openLiveWallpaperTimer
        interval: 80
        onTriggered: {
            const visibilities = root.pendingLiveWallpaperVisibility;
            root.pendingLiveWallpaperVisibility = null;
            if (visibilities && !root.hasFullscreen && Visibilities.getForActive() === visibilities)
                visibilities.liveWallpaper = true;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "controlCenter"
        description: "Open control center"
        onPressed: SettingsOpener.open()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "widgetEditor"
        description: "Open desktop widget canvas editor"
        onPressed: {
            const focusedName = Hypr.focusedMonitor?.name ?? "";
            const screen = Quickshell.screens.find(item => item.name === focusedName) ?? Quickshell.screens[0];
            WidgetEditorController.open(screen?.name ?? "", "");
        }
    }
    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "showall"
        description: "Toggle launcher, dashboard and osd"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const v = Visibilities.getForActive();
            v.launcher = v.dashboard = v.osd = v.utilities = !(v.launcher || v.dashboard || v.osd || v.utilities);
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "dashboard"
        description: "Toggle dashboard"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.dashboard = !visibilities.dashboard;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "liveWallpaper"
        description: "Toggle live wallpaper picker"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const v = Visibilities.getForActive();
            if (!v)
                return;

            if (v.liveWallpaper || root.pendingLiveWallpaperVisibility === v) {
                openLiveWallpaperTimer.stop();
                root.pendingLiveWallpaperVisibility = null;
                v.liveWallpaper = false;
                return;
            }

            // Release competing drawers and popouts before acquiring the layer-shell focus grab.
            v.launcher = false;
            v.dashboard = false;
            v.session = false;
            v.sidebar = false;
            v.utilities = false;
            v.osd = false;
            Visibilities.popoutsByMonitor.get(Hypr.focusedMonitor)?.close();

            // Activate on the next frame so the drawer loader and focus grab see a clean state.
            v.liveWallpaper = false;
            root.pendingLiveWallpaperVisibility = v;
            openLiveWallpaperTimer.restart();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "emoji"
        description: "Toggle emoji picker"
        onPressed: Emojis.toggle()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "session"
        description: "Toggle session menu"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.session = !visibilities.session;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcher"
        description: "Toggle launcher"
        onPressed: root.launcherInterrupted = false
        onReleased: {
            if (!root.launcherInterrupted && !root.hasFullscreen) {
                const visibilities = Visibilities.getForActive();
                if (!visibilities.launcher)
                    visibilities.liveWallpaper = false; // don't stack the launcher over the picker
                visibilities.launcher = !visibilities.launcher;
            }
            root.launcherInterrupted = false;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "launcherInterrupt"
        description: "Interrupt launcher keybind"
        onPressed: root.launcherInterrupted = true
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "sidebar"
        description: "Toggle sidebar"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.sidebar = !visibilities.sidebar;
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "utilities"
        description: "Toggle utilities"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.utilities = !visibilities.utilities;
        }
    }

    IpcHandler {
        function toggle(drawer: string): void {
            if (list().split("\n").includes(drawer)) {
                if (root.hasFullscreen && ["launcher", "session", "dashboard"].includes(drawer))
                    return;
                const visibilities = Visibilities.getForActive();
                visibilities[drawer] = !visibilities[drawer];
            } else {
                console.warn(lc, `Drawer "${drawer}" does not exist`);
            }
        }

        function list(): string {
            const visibilities = Visibilities.getForActive();
            return Object.keys(visibilities).filter(k => typeof visibilities[k] === "boolean").join("\n");
        }

        target: "drawers"
    }

    IpcHandler {
        function open(): void {
            SettingsOpener.open();
        }

        target: "controlCenter"
    }
    IpcHandler {
        function info(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Info);
        }

        function success(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Success);
        }

        function warn(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Warning);
        }

        function error(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Error);
        }

        target: "toaster"
    }

    LoggingCategory {
        id: lc

        name: "caelestia.qml.shortcuts"
        defaultLogLevel: LoggingCategory.Info
    }
}

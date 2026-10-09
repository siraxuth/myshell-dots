pragma Singleton

import Quickshell
import qs.components
import qs.services

Singleton {
    property var screens: new Map()
    property var bars: new Map()
    property var popoutsByMonitor: new Map()

    function load(screen: ShellScreen, visibilities: DrawerVisibilities): void {
        screens.set(Hypr.monitorFor(screen), visibilities);
    }

    function getForActive(): DrawerVisibilities {
        return screens.get(Hypr.focusedMonitor);
    }

    function registerPopouts(screen: ShellScreen, popouts: var): void {
        popoutsByMonitor.set(Hypr.monitorFor(screen), popouts);
    }
}

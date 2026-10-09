pragma Singleton

import QtQuick
import Quickshell
import qs.services

Singleton {
    function open(): void {
        const visibility = Visibilities.getForActive();
        const popouts = Visibilities.popoutsByMonitor.get(Hypr.focusedMonitor);

        if (visibility)
            visibility.utilities = false;

        if (popouts) {
            popouts.detach("network");
        } else if (visibility) {
            visibility.utilities = true;
        }
    }
}

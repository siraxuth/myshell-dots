pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia.Config
import qs.utils

// Power & idle preferences. Drives caelestia's QS IdleMonitors by swapping
// GlobalConfig.general.idle.timeouts between an AC set and a battery set based on
// UPower.onBattery. Power profile is set over D-Bus (powerprofilesctl is broken here by the
// pyenv python / missing gi). hypridle is disabled (execs.conf) so this is the only idle path.
Singleton {
    id: root

    // seconds; 0 = never
    property int acScreenOff: 600
    property int acLock: 900
    property int acSuspend: 0
    property int batScreenOff: 120
    property int batLock: 300
    property int batSuspend: 900
    property string profile: "balanced"

    function buildTimeouts(so: int, lk: int, sp: int): var {
        const t = [];
        if (so > 0)
            t.push({
                timeout: so,
                idleAction: "dpms off",
                returnAction: "dpms on"
            });
        if (lk > 0)
            t.push({
                timeout: lk,
                idleAction: "lock"
            });
        if (sp > 0)
            t.push({
                timeout: sp,
                idleAction: ["systemctl", "suspend-then-hibernate"]
            });
        return t;
    }

    // Reactive: IdleMonitors binds its Variants model to this. Recomputes when any timing or the
    // power state changes — no imperative apply, no GlobalConfig array assignment, no startup hook.
    readonly property var activeTimeouts: UPower.onBattery ? buildTimeouts(batScreenOff, batLock, batSuspend) : buildTimeouts(acScreenOff, acLock, acSuspend)

    function setTimeout(key: string, seconds: int): void {
        root[key] = seconds;
        persist();
    }

    function setProfile(p: string): void {
        root.profile = p;
        Quickshell.execDetached(["busctl", "--system", "set-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile", "s", p]);
        persist();
    }

    function persist(): void {
        storage.setText(JSON.stringify({
            acScreenOff: root.acScreenOff,
            acLock: root.acLock,
            acSuspend: root.acSuspend,
            batScreenOff: root.batScreenOff,
            batLock: root.batLock,
            batSuspend: root.batSuspend,
            profile: root.profile
        }, null, 2));
    }

    FileView {
        id: storage

        printErrors: false
        path: `${Paths.config}/power-prefs.json`
        watchChanges: true
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (d.acScreenOff !== undefined)
                    root.acScreenOff = d.acScreenOff;
                if (d.acLock !== undefined)
                    root.acLock = d.acLock;
                if (d.acSuspend !== undefined)
                    root.acSuspend = d.acSuspend;
                if (d.batScreenOff !== undefined)
                    root.batScreenOff = d.batScreenOff;
                if (d.batLock !== undefined)
                    root.batLock = d.batLock;
                if (d.batSuspend !== undefined)
                    root.batSuspend = d.batSuspend;
                if (d.profile)
                    root.profile = d.profile;
            } catch (e) {}
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                Qt.callLater(root.persist);
        }
    }
}

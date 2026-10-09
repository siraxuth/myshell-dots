pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Caelestia.Config
import qs.services
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
    property string acLidAction: "suspend"
    property string batLidAction: "hibernate"
    property string profile: "balanced"
    // GPU mode: automatic follows AC/battery, power-save always allows runtime suspend, on keeps it awake.
    property string gpuMode: "automatic"
    property int batteryBrightnessTarget: 35
    property bool gpuAvailable: false
    property bool gpuChangePending: false
    property string gpuPciAddress: ""
    property string gpuRuntimeStatus: ""
    property string gpuError: ""
    property var savedBrightness: ({})

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

    function setLidAction(key: string, action: string): void {
        if (key !== "acLidAction" && key !== "batLidAction")
            return;
        if (action !== "suspend" && action !== "hibernate")
            return;

        root[key] = action;
        persist();
    }

    function applyProfile(p: string): void {
        Quickshell.execDetached(["busctl", "--system", "set-property", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles", "ActiveProfile", "s", p]);
    }

    function applyEffectiveProfile(): void {
        applyProfile(UPower.onBattery ? "power-saver" : root.profile);
    }

    function desiredGpuControl(): string {
        if (root.gpuMode === "power-save")
            return "auto";
        if (root.gpuMode === "on")
            return "on";
        return UPower.onBattery ? "auto" : "on";
    }

    function refreshGpu(): void {
        gpuStatus.exec(["sh", "-c", "for d in /sys/bus/pci/devices/*; do [ -r \"$d/vendor\" ] || continue; [ \"$(cat \"$d/vendor\")\" = 0x10de ] || continue; c=$(cat \"$d/class\" 2>/dev/null); case \"$c\" in 0x030000|0x030200) printf '%s|%s|%s\\n' \"${d##*/}\" \"$(cat \"$d/power/control\" 2>/dev/null)\" \"$(cat \"$d/power/runtime_status\" 2>/dev/null)\";; esac; done"]);
    }

    function applyGpuPolicy(): void {
        if (!root.gpuAvailable || root.gpuChangePending)
            return;
        const target = desiredGpuControl();
        // Avoid repeated polkit prompts: only write when current control differs.
        if ((target === "auto") === root.gpuPowerSaving)
            return;
        const script = "set -eu; mode=\"$1\"; gpu=\"$2\"; case \"$mode\" in auto|on) ;; *) exit 2;; esac; printf '%s\\n' \"$gpu\" | grep -Eq '^[[:xdigit:]]{4}:[[:xdigit:]]{2}:[[:xdigit:]]{2}\\.[0-7]$' || exit 2; slot=\"${gpu%.*}\"; found=0; for d in /sys/bus/pci/devices/\"$slot\".*; do [ -r \"$d/vendor\" ] || continue; [ \"$(cat \"$d/vendor\")\" = 0x10de ] || continue; printf '%s\\n' \"$mode\" > \"$d/power/control\"; found=1; done; [ \"$found\" = 1 ]";
        root.gpuChangePending = true;
        root.gpuError = "";
        gpuCommand.exec(["pkexec", "sh", "-c", script, "caelestia-gpu-power", target, root.gpuPciAddress]);
    }

    function setGpuMode(mode: string): void {
        if (["automatic", "power-save", "on"].indexOf(mode) < 0)
            return;
        root.gpuMode = mode;
        persist();
        applyGpuPolicy();
    }

    function applyBatteryBrightness(force: bool): void {
        if (!UPower.onBattery)
            return;
        const target = root.batteryBrightnessTarget / 100;
        for (const monitor of Brightness.monitors) {
            if (!monitor.ready)
                continue;
            const key = monitor.modelData.name;
            if (root.savedBrightness[key] === undefined && monitor.brightness > target) {
                root.savedBrightness[key] = monitor.brightness;
                monitor.setBrightness(target);
            } else if (force && root.savedBrightness[key] !== undefined && monitor.brightness > target) {
                monitor.setBrightness(target);
            }
        }
    }

    function restoreBrightness(): void {
        const pending = ({});
        for (const key in root.savedBrightness)
            pending[key] = root.savedBrightness[key];
        for (const monitor of Brightness.monitors) {
            const key = monitor.modelData.name;
            const value = pending[key];
            if (monitor.ready && value !== undefined) {
                monitor.setBrightness(value);
                delete pending[key];
            }
        }
        root.savedBrightness = pending;
    }

    function setBatteryBrightnessTarget(value: int): void {
        root.batteryBrightnessTarget = Math.max(20, Math.min(60, value));
        persist();
        applyBatteryBrightness(true);
    }

    function setProfile(p: string): void {
        root.profile = p;
        applyEffectiveProfile();
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
            acLidAction: root.acLidAction,
            batLidAction: root.batLidAction,
            profile: root.profile,
            gpuMode: root.gpuMode,
            batteryBrightnessTarget: root.batteryBrightnessTarget
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
                if (d.acLidAction === "suspend" || d.acLidAction === "hibernate")
                    root.acLidAction = d.acLidAction;
                if (d.batLidAction === "suspend" || d.batLidAction === "hibernate")
                    root.batLidAction = d.batLidAction;
                if (d.profile)
                    root.profile = d.profile;
                if (["automatic", "power-save", "on"].includes(d.gpuMode))
                    root.gpuMode = d.gpuMode;
                if (Number.isFinite(d.batteryBrightnessTarget))
                    root.batteryBrightnessTarget = Math.max(20, Math.min(60, d.batteryBrightnessTarget));
            } catch (e) {}
            // ppd's live ActiveProfile is its own persisted state, independent of this file —
            // it can drift (e.g. left on power-saver from a previous session) without us ever
            // pushing our config back. Enforce it on every load so the stored pref is the truth.
            root.applyEffectiveProfile();
            Qt.callLater(() => {
                root.refreshGpu();
                root.applyBatteryBrightness(false);
            });
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                Qt.callLater(root.persist);
        }
    }

    property bool gpuPowerSaving: false

    Process {
        id: gpuStatus
        stdout: StdioCollector {
            onStreamFinished: {
                const values = text.trim().split("\n")[0].split("|");
                root.gpuAvailable = values.length === 3 && values[0].length > 0;
                root.gpuPciAddress = root.gpuAvailable ? values[0] : "";
                root.gpuPowerSaving = root.gpuAvailable && values[1] === "auto";
                root.gpuRuntimeStatus = root.gpuAvailable ? values[2] : "";
                root.applyGpuPolicy();
            }
        }
    }

    Process {
        id: gpuCommand
        onExited: (exitCode, exitStatus) => {
            root.gpuChangePending = false;
            if (exitCode !== 0)
                root.gpuError = qsTr("Could not change GPU power mode. Authorization may have been cancelled.");
            root.refreshGpu();
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: {
            if (UPower.onBattery)
                root.applyBatteryBrightness(false);
            else
                root.restoreBrightness();
            if (!root.gpuChangePending)
                root.refreshGpu();
        }
    }

    Connections {
        target: UPower
        function onOnBatteryChanged(): void {
            root.applyEffectiveProfile();
            if (UPower.onBattery)
                root.applyBatteryBrightness(false);
            else
                root.restoreBrightness();
            root.applyGpuPolicy();
        }
    }

    Connections {
        target: Brightness
        function onMonitorsChanged(): void {
            if (UPower.onBattery)
                Qt.callLater(() => root.applyBatteryBrightness(false));
        }
    }
}

pragma Singleton

import QtQuick
import QtMultimedia
import Quickshell
import Caelestia.Config

// Small UI sound API used by widgets and transient controls.
// Names are logical IDs so callers don't need to know where sound files live.
Singleton {
    id: root

    readonly property int invalidHandle: -1
    readonly property int chargeHandle: 1
    property bool enabled: true
    property real masterVolume: 0.75
    property bool chargePending: false
    property bool confirmPending: false

    function sourceFor(soundId: string): url {
        const path = String(soundId || "").trim();
        if (!path)
            return "";
        if (path.startsWith("file://"))
            return path;
        if (path.startsWith("/"))
            return `file://${path}`;
        return Qt.resolvedUrl(path.startsWith("assets/") ? `../${path}` : `../assets/${path}`);
    }

    SoundEffect {
        id: chargeLoop
        loops: SoundEffect.Infinite
        volume: 0.42
        onStatusChanged: if (status === SoundEffect.Ready && root.chargePending && !playing) play()
    }

    SoundEffect {
        id: confirmSound
        loops: 1
        volume: 0.58
        onStatusChanged: if (status === SoundEffect.Ready && root.confirmPending) {
            root.confirmPending = false;
            play();
        }
    }

    function playNotification(): void {
        if (!enabled || !Config.notifs.soundEnabled)
            return;

        const volume = Math.max(0, Math.min(1, Config.notifs.soundVolume));
        Quickshell.execDetached([
            "pw-play",
            `--volume=${volume}`,
            `${Quickshell.shellDir}/assets/sounds/notification-${Config.notifs.soundId === "crisp" ? "crisp" : "soft"}.wav`
        ]);
    }

    function previewNotification(): void {
        if (!Config.notifs.soundEnabled)
            return;
        playNotification();
    }

    function playUntilStopped(soundId: string, gain: real, _restart: bool): int {
        if (!enabled)
            return invalidHandle;
        chargePending = true;
        chargeLoop.source = sourceFor(soundId);
        chargeLoop.volume = Math.max(0, Math.min(1, gain * masterVolume));
        if (chargeLoop.status === SoundEffect.Ready && !chargeLoop.playing)
            chargeLoop.play();
        return chargeHandle;
    }

    function stopSfx(handle: int): void {
        if (handle === chargeHandle) {
            chargePending = false;
            chargeLoop.stop();
        }
    }

    function playSfx(soundId: string): int {
        if (enabled) {
            confirmPending = true;
            confirmSound.source = sourceFor(soundId);
            confirmSound.volume = Math.max(0, Math.min(1, 0.78 * masterVolume));
            confirmSound.stop();
            if (confirmSound.status === SoundEffect.Ready) {
                confirmPending = false;
                confirmSound.play();
            }
            return 2;
        }
        return invalidHandle;
    }
}

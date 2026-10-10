pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Foot reads its configuration when a terminal starts. Keep the controls in
// Control Center backed by the real foot.ini so every new window uses them.
Singleton {
    id: root

    property bool blurEnabled: true
    property real opacity: 0.88
    property bool cursorBlinkEnabled: true
    property int cursorBlinkRate: 600
    property bool loaded: false

    function readOption(contents: string, sectionName: string, key: string, fallback: string): string {
        let inSection = false;
        const lines = contents.split(/\r?\n/);
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            const section = line.match(/^\s*\[([^\]]+)\]\s*$/);
            if (section) {
                inSection = section[1] === sectionName;
                continue;
            }
            if (!inSection)
                continue;
            const option = line.match(new RegExp(`^\\s*${key}\\s*=\\s*([^#;]*?)\\s*(?:[#;].*)?$`, "i"));
            if (option)
                return option[1].trim();
        }
        return fallback;
    }

    function setOption(contents: string, sectionName: string, key: string, value: string): string {
        const lines = contents.split(/\r?\n/);
        let sectionStart = -1;
        let sectionEnd = lines.length;

        for (let i = 0; i < lines.length; i++) {
            const section = lines[i].match(/^\s*\[([^\]]+)\]\s*$/);
            if (!section)
                continue;
            if (sectionStart >= 0) {
                sectionEnd = i;
                break;
            }
            if (section[1] === sectionName)
                sectionStart = i;
        }

        if (sectionStart < 0) {
            if (lines.length && lines[lines.length - 1] !== "")
                lines.push("");
            lines.push(`[${sectionName}]`, `${key}=${value}`);
            return lines.join("\n");
        }

        const optionPattern = new RegExp(`^\\s*${key}\\s*=`, "i");
        for (let i = sectionStart + 1; i < sectionEnd; i++) {
            if (optionPattern.test(lines[i])) {
                lines[i] = `${key}=${value}`;
                return lines.join("\n");
            }
        }

        lines.splice(sectionEnd, 0, `${key}=${value}`);
        return lines.join("\n");
    }

    function setBlurEnabled(enabled: bool): void {
        if (root.blurEnabled === enabled)
            return;
        root.blurEnabled = enabled;
        writeTimer.restart();
    }

    function setOpacity(value: real): void {
        const next = Math.max(0.55, Math.min(1.0, value));
        if (Math.abs(root.opacity - next) < 0.005)
            return;
        root.opacity = next;
        writeTimer.restart();
    }

    function setCursorBlinkEnabled(enabled: bool): void {
        if (root.cursorBlinkEnabled === enabled)
            return;
        root.cursorBlinkEnabled = enabled;
        writeTimer.restart();
    }

    function setCursorBlinkRate(value: int): void {
        const next = Math.max(250, Math.min(1000, value));
        if (root.cursorBlinkRate === next)
            return;
        root.cursorBlinkRate = next;
        writeTimer.restart();
    }

    Timer {
        id: writeTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (!root.loaded)
                return;
            let contents = footConfig.text();
            contents = root.setOption(contents, "colors-dark", "alpha", root.opacity.toFixed(2));
            contents = root.setOption(contents, "colors-dark", "blur", root.blurEnabled ? "yes" : "no");
            contents = root.setOption(contents, "cursor", "blink", root.cursorBlinkEnabled ? "yes" : "no");
            contents = root.setOption(contents, "cursor", "blink-rate", `${root.cursorBlinkRate}`);
            footConfig.setText(contents);
        }
    }

    FileView {
        id: footConfig

        path: `${Paths.data}/foot/foot.ini`
        watchChanges: true
        printErrors: false

        onLoaded: {
            const contents = text();
            const alpha = Number(root.readOption(contents, "colors-dark", "alpha", "0.88"));
            const blinkRate = Number(root.readOption(contents, "cursor", "blink-rate", "600"));
            root.opacity = Number.isFinite(alpha) ? Math.max(0.55, Math.min(1.0, alpha)) : 0.88;
            root.blurEnabled = root.readOption(contents, "colors-dark", "blur", "no").toLowerCase() === "yes";
            root.cursorBlinkEnabled = root.readOption(contents, "cursor", "blink", "no").toLowerCase() === "yes";
            root.cursorBlinkRate = Number.isFinite(blinkRate) ? Math.max(250, Math.min(1000, Math.round(blinkRate))) : 600;
            root.loaded = true;
        }
        onFileChanged: reload()
        onSaveFailed: error => console.warn(`Foot settings could not be saved: ${FileViewError.toString(error)}`)
    }
}

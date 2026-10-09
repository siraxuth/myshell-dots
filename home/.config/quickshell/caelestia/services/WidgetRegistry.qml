pragma Singleton

import QtQuick
import Caelestia.Config
import qs.services
import qs.utils

// Caelestia-native catalog for the desktop widget editor. The identifiers and
// variants follow the Serpantinum widget collection; rendering uses local faces.
QtObject {
    id: root

    readonly property var definitions: ({
        visualizer: { name: qsTr("Visualizer"), icon: "equalizer", size: [540, 180], variant: "bars", variants: ["bars", "continuous"] },
        time: { name: qsTr("Clock"), icon: "schedule", size: [250, 120], variant: "digital", variants: ["digital", "analog", "minimal", "material", "materialAnalog", "lumen"] },
        calendar: { name: qsTr("Calendar"), icon: "calendar_month", size: [340, 390], variant: "month", variants: ["month"] },
        music: { name: qsTr("Music"), icon: "music_note", size: [440, 240], variant: "full", variants: ["full", "round", "lyrics", "simpleLyrics"] },
        weather: { name: qsTr("Weather"), icon: "cloud", size: [250, 120], variant: "compact", variants: ["compact", "full", "round"] },
        image: { name: qsTr("Image"), icon: "image", size: [300, 200], variant: "rect", variants: ["rect", "rounded", "round"] },
        user: { name: qsTr("User"), icon: "person", size: [260, 140], variant: "default", variants: ["default"] },
        cpu: { name: qsTr("CPU"), icon: "memory", size: [180, 130], variant: "default", variants: ["default"] },
        ram: { name: qsTr("Memory"), icon: "developer_board", size: [180, 130], variant: "default", variants: ["default"] },
        temp: { name: qsTr("Temperature"), icon: "device_thermostat", size: [180, 130], variant: "default", variants: ["default"] },
        disk: { name: qsTr("Disk"), icon: "storage", size: [180, 130], variant: "default", variants: ["default"] },
        battery: { name: qsTr("Battery"), icon: "battery_full", size: [260, 90], variant: "default", variants: ["default"] },
        github: { name: "GitHub", icon: "code", size: [540, 180], variant: "default", variants: ["default"] },
        // Compatibility faces preserve existing Caelestia layouts through migration.
        arch: { name: qsTr("Arch"), icon: "star", size: [420, 420], variant: "default", variants: ["default"] },
        resources: { name: qsTr("System resources"), icon: "memory", size: [300, 100], variant: "default", variants: ["default"] }
    })

    property var customDefinitions: ({})
    readonly property var ids: Object.keys(definitions).concat(Object.keys(customDefinitions).filter(type => !definitions[type]))

    function get(type: string): var {
        if (!customDefinitions[type]) return definitions[type] ?? definitions.time;
        const custom = customDefinitions[type];
        return Object.assign({}, custom, {
            size: custom.size ?? [custom.defaultWidth ?? 250, custom.defaultHeight ?? 120],
            variant: custom.variant ?? custom.defaultVariant ?? "default",
            variants: Array.isArray(custom.variants) ? custom.variants : Object.keys(custom.variants ?? {})
        });
    }

    function defaultVariant(type: string): string {
        return get(type).variant;
    }

    function defaultSize(type: string): var {
        return get(type).size;
    }

    function sizeForVariant(type: string, variant: string): var {
        const size = defaultSize(type);
        if (type === "music" && variant === "round")
            return [300, 300];
        if (["round", "analog", "materialAnalog", "lumen"].includes(variant)) {
            const diameter = Math.max(size[0], size[1]);
            return [diameter, diameter];
        }
        return size;
    }

    function constrainSize(type: string, variant: string, width: real, height: real, lockAspect: bool): var {
        const rules = {
            visualizer: { minW: 50, minH: 50, minA: 0, maxA: 99999 },
            time: variant === "minimal" ? { minW: 80, minH: 40, minA: 1.2, maxA: 5 } : ["analog", "materialAnalog", "lumen"].includes(variant) ? { minW: 100, minH: 100, minA: 1, maxA: 1 } : variant === "material" ? { minW: 100, minH: 100, minA: 0.7, maxA: 1.3 } : { minW: 120, minH: 120, minA: 0.8, maxA: 2.8 },
            music: variant === "round" ? { minW: 150, minH: 150, minA: 1, maxA: 1 } : variant === "lyrics" ? { minW: 180, minH: 60, minA: 1.2, maxA: 5 } : variant === "simpleLyrics" ? { minW: 180, minH: 60, minA: 0.5, maxA: 8 } : { minW: 150, minH: 64, minA: 2.4, maxA: 3.2 },
            weather: variant === "full" ? { minW: 420, minH: 260, minA: 1.6, maxA: 1.6 } : variant === "round" ? { minW: 90, minH: 90, minA: 1, maxA: 1 } : { minW: 90, minH: 90, minA: 0.7, maxA: 2.2 },
            image: variant === "round" ? { minW: 40, minH: 40, minA: 1, maxA: 1 } : { minW: 30, minH: 30, minA: 0.02, maxA: 50 },
            cpu: { minW: 100, minH: 70, minA: 0.6, maxA: 3 }, ram: { minW: 100, minH: 70, minA: 0.6, maxA: 3 }, disk: { minW: 100, minH: 70, minA: 0.6, maxA: 3 }, temp: { minW: 100, minH: 70, minA: 0.6, maxA: 3 }
        }[type] ?? { minW: 70, minH: 60, minA: 0, maxA: 99999 };
        let w = Math.max(rules.minW, width);
        let h = Math.max(rules.minH, height);
        const ratio = w / Math.max(1, h);
        if (lockAspect || rules.minA === rules.maxA) {
            const fixed = lockAspect && rules.minA !== rules.maxA ? width / Math.max(1, height) : rules.minA;
            if (w / h > fixed) h = w / fixed;
            else w = h * fixed;
        } else if (ratio < rules.minA) {
            w = h * rules.minA;
        } else if (ratio > rules.maxA) {
            h = w / rules.maxA;
        }
        return { w: Math.round(Math.max(rules.minW, w)), h: Math.round(Math.max(rules.minH, h)) };
    }

    function typeList(): var {
        return ids.map(id => Object.assign({ id }, get(id)));
    }

    function registerType(type: string, definition: var): void {
        if (!type || !definition) return;
        const next = Object.assign({}, customDefinitions);
        next[type] = definition;
        customDefinitions = next;
    }

    function unregisterType(type: string): void {
        if (!customDefinitions[type]) return;
        const next = Object.assign({}, customDefinitions);
        delete next[type];
        customDefinitions = next;
    }

    function safeArea(screenWidth: real, screenHeight: real, stretchWidth: bool, stretchHeight: bool): var {
        const barInset = Config.border.thickness + Tokens.sizes.bar.innerWidth;
        const safeLeft = stretchWidth || !BarPosition.isLeft(BarPositionPrefs.position) ? 0 : barInset;
        const safeRight = stretchWidth || !BarPosition.isRight(BarPositionPrefs.position) ? 0 : barInset;
        const safeTop = stretchHeight || !BarPosition.isTop(BarPositionPrefs.position) ? 0 : barInset;
        const safeBottom = stretchHeight || !BarPosition.isBottom(BarPositionPrefs.position) ? 0 : barInset;
        return { x: safeLeft, y: safeTop, width: Math.max(0, screenWidth - safeLeft - safeRight), height: Math.max(0, screenHeight - safeTop - safeBottom) };
    }

    function sizeFor(widget: var, screenWidth: real, screenHeight: real): var {
        const dimension = (raw, extent, fallback) => {
            if (typeof raw === "string" && raw.trim().endsWith("%")) return Math.round(parseFloat(raw) * extent / 100);
            const n = Number(raw ?? fallback);
            return Number.isFinite(n) ? n : fallback;
        };
        return {
            width: dimension(widget.wWidth ?? widget.width ?? widget.w, screenWidth, 250),
            height: dimension(widget.wHeight ?? widget.height ?? widget.h, screenHeight, 120)
        };
    }

    function positionFor(widget: var, screenWidth: real, screenHeight: real): var {
        const rawAnchor = String(widget.anchor ?? widget.anchors ?? "").toLowerCase().replace(/[-_]/g, " ").trim();
        const parts = rawAnchor ? rawAnchor.split(/\s+/) : [];
        let horizontal = "left";
        let vertical = "top";

        if (parts.length === 1) {
            if (parts[0] === "top" || parts[0] === "bottom") {
                horizontal = "center";
                vertical = parts[0];
            } else if (parts[0] === "right" || parts[0] === "left") {
                horizontal = parts[0];
                vertical = "center";
            } else if (parts[0] === "center" || parts[0] === "middle") {
                horizontal = vertical = "center";
            }
        } else {
            for (const part of parts) {
                if (part === "left" || part === "right") horizontal = part;
                else if (part === "top" || part === "bottom") vertical = part;
                else if (part === "center" || part === "middle") {
                    if (parts.includes("left") || parts.includes("right")) vertical = "center";
                    if (parts.includes("top") || parts.includes("bottom")) horizontal = "center";
                    if (parts.length === 2 && !parts.some(p => ["left", "right", "top", "bottom"].includes(p))) horizontal = vertical = "center";
                }
            }
        }

        const anchorH = String(widget.anchorH ?? widget.anchorX ?? widget.horizontalAnchor ?? widget.hAnchor ?? widget.anchorHorizontal ?? "").toLowerCase();
        const anchorV = String(widget.anchorV ?? widget.anchorY ?? widget.verticalAnchor ?? widget.vAnchor ?? widget.anchorVertical ?? "").toLowerCase();
        if (anchorH === "middle") horizontal = "center";
        else if (["left", "center", "right"].includes(anchorH)) horizontal = anchorH;
        if (anchorV === "middle") vertical = "center";
        else if (["top", "center", "bottom"].includes(anchorV)) vertical = anchorV;

        const size = sizeFor(widget, screenWidth, screenHeight);
        const width = size.width;
        const height = size.height;
        const offset = (raw, extent) => typeof raw === "string" && raw.trim().endsWith("%") ? Math.round(parseFloat(raw) * extent / 100) : (Number(raw) || 0);
        const offsetX = offset(widget.wX ?? widget.offsetX ?? widget.x, screenWidth);
        const offsetY = offset(widget.wY ?? widget.offsetY ?? widget.y, screenHeight);
        const stretchWidth = Boolean(widget.wStretchWidth ?? widget.stretchWidth ?? widget.wProps?.stretchWidth);
        const stretchHeight = Boolean(widget.wStretchHeight ?? widget.stretchHeight ?? widget.wProps?.stretchHeight);
        const safe = safeArea(screenWidth, screenHeight, stretchWidth, stretchHeight);
        const x = stretchWidth ? 0 : horizontal === "right" ? safe.x + safe.width - width - offsetX : horizontal === "center" ? safe.x + (safe.width - width) / 2 + offsetX : safe.x + offsetX;
        const y = stretchHeight ? 0 : vertical === "bottom" ? safe.y + safe.height - height - offsetY : vertical === "center" ? safe.y + (safe.height - height) / 2 + offsetY : safe.y + offsetY;
        return { x: Math.round(x), y: Math.round(y) };
    }
}

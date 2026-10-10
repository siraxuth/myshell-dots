pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Per-monitor widget layouts. WidgetLayoutStore owns the disk file for each
// monitor; this singleton is the shared in-memory model for the shell and CC.
Singleton {
    id: root

    property var layouts: ({})
    property var readyScreens: ({})
    property var histories: ({})
    property var saveStates: ({})
    property bool restoringHistory: false
    property bool legacyReady: false
    property var legacyWidgets: []

    signal layoutChanged(string screenName)
    signal layoutReady(string screenName)
    signal retrySave(string screenName)

    function safeName(name: string): string {
        return String(name || "default").replace(/[^a-zA-Z0-9_-]/g, "_");
    }

    function layoutFor(screenName: string): var {
        return layouts[screenName] ?? [];
    }

    function normalizeImagePath(path: var): string {
        let value = String(path ?? "").trim();
        if (!value || value.startsWith("file://"))
            return value;
        const home = Quickshell.env("HOME") || "/home";
        if (value.startsWith("~/"))
            return `${home}/${value.slice(2)}`;
        if (value.startsWith("home/"))
            return `/${value}`;
        if (!value.startsWith("/"))
            return `${home}/${value}`;
        return value;
    }

    function isReady(screenName: string): bool {
        return readyScreens[screenName] === true;
    }

    function setLoadedLayout(screenName: string, items: var): void {
        const nextLayouts = Object.assign({}, layouts);
        const nextReady = Object.assign({}, readyScreens);
        nextLayouts[screenName] = Array.isArray(items) ? items : [];
        nextReady[screenName] = true;
        layouts = nextLayouts;
        readyScreens = nextReady;
        layoutReady(screenName);
    }

    function normalizeLayout(items: var): var {
        if (!Array.isArray(items))
            return [];
        return items.map((raw, index) => {
            const item = Object.assign({}, raw ?? {});
            const rawType = item.wType ?? item.type ?? "time";
            const type = ({
                    clock: "time",
                    media: "music",
                    visualiser: "visualizer"
                })[rawType] ?? rawType;
            const definition = WidgetRegistry.get(type);
            const rawScale = Number(item.wScale ?? item.scale ?? 1);
            const scale = Number.isFinite(rawScale) && rawScale > 0 ? rawScale : 1;
            const rawOpacity = Number(item.wOpacity ?? item.opacity ?? 1);
            const rawRotation = Number(item.wRotation ?? item.rotation ?? 0);
            const size = definition.size;
            const requestedVariant = item.wVariant ?? item.variant ?? definition.variant;
            const variants = definition.variants ?? [];
            const custom = Object.assign({}, item.wProps ?? {});
            for (const key of ["username", "displayName", "noteText", "textColor", "accentColor", "playerIdentity", "showAlbumArt", "showControls", "showProgress", "showVisualizer", "lyricsLines", "lyricsAlignment", "bgVisible", "bgColor", "bgColor2", "bgGradient", "bgOpacity", "bgRadius", "bgBorderColor", "bgBorderWidth", "backgroundColor", "backgroundOpacity", "backgroundRadius", "stretchWidth", "stretchHeight"]) {
                if (item[key] !== undefined && custom[key] === undefined)
                    custom[key] = item[key];
            }
            if (custom.bgColor === undefined && custom.backgroundColor !== undefined)
                custom.bgColor = custom.backgroundColor;
            if (custom.bgOpacity === undefined && custom.backgroundOpacity !== undefined)
                custom.bgOpacity = custom.backgroundOpacity;
            if (custom.bgRadius === undefined && custom.backgroundRadius !== undefined)
                custom.bgRadius = custom.backgroundRadius;
            item.wId = String(item.wId ?? item.id ?? `widget_${index}_${Date.now()}`);
            item.wType = type;
            item.wVariant = variants.includes(requestedVariant) ? requestedVariant : definition.variant;
            item.wX = item.wX ?? item.offsetX ?? item.x ?? 100;
            item.wY = item.wY ?? item.offsetY ?? item.y ?? 100;
            item.wWidth = item.wWidth ?? item.width ?? item.w ?? Math.round(size[0] * scale);
            item.wHeight = item.wHeight ?? item.height ?? item.h ?? Math.round(size[1] * scale);
            item.wOpacity = Number.isFinite(rawOpacity) ? Math.max(0.15, Math.min(1, rawOpacity)) : 1;
            item.wRotation = Number.isFinite(rawRotation) ? ((Math.round(rawRotation) % 360) + 360) % 360 : 0;
            item.wImagePath = normalizeImagePath(item.wImagePath ?? item.imagePath ?? item.path ?? "");
            item.wProps = custom;
            item.enabled = item.enabled !== false;
            return item;
        });
    }

    function canUndo(name: string): bool {
        return (histories[name]?.undo.length ?? 0) > 0;
    }
    function canRedo(name: string): bool {
        return (histories[name]?.redo.length ?? 0) > 0;
    }
    function setSaveState(name: string, state: string): void {
        const next = Object.assign({}, saveStates);
        next[name] = state;
        saveStates = next;
    }
    function undo(name: string): void {
        restoreHistory(name, false);
    }
    function redo(name: string): void {
        restoreHistory(name, true);
    }
    function restoreHistory(name: string, redo: bool): void {
        const h = histories[name];
        if (!h || !(redo ? h.redo : h.undo).length)
            return;
        const undoStack = h.undo.slice();
        const redoStack = h.redo.slice();
        const source = redo ? redoStack : undoStack;
        (redo ? undoStack : redoStack).push(JSON.stringify(layoutFor(name)));
        const layout = JSON.parse(source.pop());
        const next = Object.assign({}, histories);
        next[name] = {
            undo: undoStack.slice(-50),
            redo: redoStack.slice(-50),
            key: "",
            time: 0
        };
        histories = next;
        restoringHistory = true;
        setLayout(name, layout);
        restoringHistory = false;
    }

    function setLayout(screenName: string, items: var, historyKey: string): void {
        if (!isReady(screenName))
            return;
        const before = JSON.stringify(layoutFor(screenName));
        if (before === JSON.stringify(items))
            return;
        if (!restoringHistory) {
            const previous = histories[screenName] ?? {
                undo: [],
                redo: [],
                key: "",
                time: 0
            };
            const stack = previous.undo.slice();
            const now = Date.now();
            if (!historyKey || previous.key !== historyKey || now - previous.time > 600)
                stack.push(before);
            const history = Object.assign({}, histories);
            history[screenName] = {
                undo: stack.slice(-50),
                redo: [],
                key: historyKey,
                time: now
            };
            histories = history;
        }
        setSaveState(screenName, "saving");
        const nextLayouts = Object.assign({}, layouts);
        nextLayouts[screenName] = Array.isArray(items) ? items : [];
        layouts = nextLayouts;
        layoutChanged(screenName);
    }

    function updateWidget(screenName: string, id: string, key: string, value: var): void {
        const fields = {};
        fields[key] = value;
        updateWidgetFields(screenName, id, fields);
    }

    function updateWidgetFields(screenName: string, id: string, fields: var): void {
        if (!isReady(screenName))
            return;
        const items = layoutFor(screenName).map(item => Object.assign({}, item));
        const index = items.findIndex(item => String(item.wId) === String(id));
        if (index < 0)
            return;
        Object.assign(items[index], fields);
        setLayout(screenName, items, `${id}:${Object.keys(fields).join(",")}`);
    }

    function storedPosition(screenName: string, x: real, y: real): var {
        const screen = Quickshell.screens.find(entry => entry.name === screenName);
        const safe = screen ? WidgetRegistry.safeArea(screen.width, screen.height, false, false) : {
            x: 0,
            y: 0
        };
        return {
            wX: Math.round(x - safe.x),
            wY: Math.round(y - safe.y)
        };
    }

    function setWidgetPosition(screenName: string, id: string, x: real, y: real, width: real, height: real): void {
        const item = layoutFor(screenName).find(entry => String(entry.wId) === String(id));
        if (!item)
            return;
        updateWidgetFields(screenName, id, Object.assign(storedPosition(screenName, x, y), {
            wWidth: Math.round(width),
            wHeight: Math.round(height),
            wProps: Object.assign({}, item.wProps ?? {}, {
                stretchWidth: false,
                stretchHeight: false
            }),
            stretchWidth: false,
            stretchHeight: false,
            anchor: "",
            anchors: "",
            anchorH: "",
            anchorV: "",
            anchorX: "",
            anchorY: "",
            horizontalAnchor: "",
            verticalAnchor: "",
            hAnchor: "",
            vAnchor: "",
            anchorHorizontal: "",
            anchorVertical: ""
        }));
    }

    function setWidgetAnchor(screenName: string, id: string, horizontal: string, vertical: string, x: real, y: real, width: real, height: real, screenWidth: real, screenHeight: real): void {
        const safe = WidgetRegistry.safeArea(screenWidth, screenHeight, false, false);
        const offsetX = horizontal === "right" ? safe.x + safe.width - width - x : horizontal === "center" ? x - (safe.x + (safe.width - width) / 2) : x - safe.x;
        const offsetY = vertical === "bottom" ? safe.y + safe.height - height - y : vertical === "center" ? y - (safe.y + (safe.height - height) / 2) : y - safe.y;
        updateWidgetFields(screenName, id, {
            anchor: "",
            anchorH: horizontal,
            anchorV: vertical,
            wX: Math.round(offsetX),
            wY: Math.round(offsetY)
        });
    }

    function updateWidgetProperty(screenName: string, id: string, key: string, value: var): void {
        if (!isReady(screenName))
            return;
        const items = layoutFor(screenName).map(item => Object.assign({}, item, {
                wProps: Object.assign({}, item.wProps ?? {})
            }));
        const index = items.findIndex(item => String(item.wId) === String(id));
        if (index < 0)
            return;
        items[index].wProps[key] = value;
        setLayout(screenName, items, `${id}:props:${key}`);
    }

    function setVariant(screenName: string, id: string, variant: string): void {
        if (!isReady(screenName))
            return;
        const item = layoutFor(screenName).find(entry => String(entry.wId) === String(id));
        if (!item)
            return;
        const size = WidgetRegistry.constrainSize(item.wType, variant, Number(item.wWidth ?? 250), Number(item.wHeight ?? 120), false);
        const fields = {
            wVariant: variant,
            wWidth: size.w,
            wHeight: size.h
        };
        updateWidgetFields(screenName, id, fields);
    }

    function addWidget(screenName: string, type: string, screenWidth: real, screenHeight: real): string {
        if (!isReady(screenName))
            return "";
        const definition = WidgetRegistry.get(type);
        const size = definition.size;
        const safe = WidgetRegistry.safeArea(screenWidth, screenHeight, false, false);
        const id = `widget_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
        const items = layoutFor(screenName).map(item => Object.assign({}, item));
        items.push({
            wId: id,
            wType: type,
            wVariant: definition.variant,
            wX: Math.max(0, (safe.width - size[0]) / 2 + (items.length % 5) * 24),
            wY: Math.max(0, (safe.height - size[1]) / 2 + (items.length % 5) * 24),
            wWidth: size[0],
            wHeight: size[1],
            wOpacity: 1,
            wRotation: 0,
            wImagePath: "",
            enabled: true,
            wProps: {}
        });
        setLayout(screenName, items);
        return id;
    }

    function removeWidget(screenName: string, id: string): void {
        if (!isReady(screenName))
            return;
        setLayout(screenName, layoutFor(screenName).filter(item => String(item.wId) !== String(id)));
    }

    function clearWidgets(screenName: string): void {
        if (!isReady(screenName))
            return;
        setLayout(screenName, []);
    }

    function moveWidget(screenName: string, id: string, direction: int): void {
        if (!isReady(screenName))
            return;
        const items = layoutFor(screenName).map(item => Object.assign({}, item));
        const index = items.findIndex(item => String(item.wId) === String(id));
        const target = index + direction;
        if (index < 0 || target < 0 || target >= items.length)
            return;
        const selected = items[index];
        items[index] = items[target];
        items[target] = selected;
        setLayout(screenName, items);
    }

    function migrateLegacy(): var {
        const positionMap = {
            "top-left": "top left",
            "top-center": "top center",
            "top-right": "top right",
            "middle-left": "center left",
            "middle-center": "center",
            "middle-right": "center right",
            "bottom-left": "bottom left",
            "bottom-center": "bottom center",
            "bottom-right": "bottom right"
        };
        const converted = legacyWidgets.map((item, index) => {
            const legacyType = item.wType ?? item.type ?? "clock";
            const type = ({
                    clock: "time",
                    media: "music",
                    visualiser: "visualizer"
                })[legacyType] ?? legacyType;
            const def = WidgetRegistry.get(type);
            const rawScale = Number(item.wScale ?? item.scale ?? 1);
            const scale = Number.isFinite(rawScale) ? Math.max(0.5, Math.min(2.5, rawScale)) : 1;
            const props = Object.assign({}, item.wProps ?? {});
            for (const key of ["username", "displayName", "noteText", "textColor", "accentColor", "playerIdentity", "showAlbumArt", "showControls", "showProgress", "showVisualizer", "lyricsLines", "lyricsAlignment", "bgColor", "bgColor2", "bgGradient", "bgOpacity", "bgRadius", "bgBorderColor", "bgBorderWidth", "backgroundColor", "backgroundOpacity", "backgroundRadius", "stretchWidth", "stretchHeight"]) {
                if (item[key] !== undefined && props[key] === undefined)
                    props[key] = item[key];
            }
            if (props.bgColor === undefined && typeof item.background === "string")
                props.bgColor = item.background;
            if (props.bgColor === undefined && props.backgroundColor !== undefined)
                props.bgColor = props.backgroundColor;
            if (props.bgOpacity === undefined && props.backgroundOpacity !== undefined)
                props.bgOpacity = props.backgroundOpacity;
            if (props.bgRadius === undefined && props.backgroundRadius !== undefined)
                props.bgRadius = props.backgroundRadius;
            props.bgVisible = (typeof item.background === "boolean" ? item.background : true) && item.bgVisible !== false && props.bgVisible !== false;
            return {
                wId: String(item.wId ?? item.id ?? `legacy_${index}_${legacyType}`),
                wType: type,
                wVariant: item.wVariant ?? item.variant ?? def.variant,
                wX: item.wX ?? item.x ?? 0,
                wY: item.wY ?? item.y ?? 0,
                wWidth: item.wWidth ?? item.width ?? Math.round(def.size[0] * scale),
                wHeight: item.wHeight ?? item.height ?? Math.round(def.size[1] * scale),
                wOpacity: item.wOpacity ?? item.opacity ?? 1,
                wRotation: item.wRotation ?? item.rotation ?? 0,
                wImagePath: item.wImagePath ?? item.imagePath ?? item.path ?? "",
                enabled: item.enabled !== false,
                anchor: item.anchor ?? positionMap[item.position] ?? "bottom left",
                anchorH: item.anchorH ?? item.anchorX,
                anchorV: item.anchorV ?? item.anchorY,
                wProps: props
            };
        });
        return normalizeLayout(converted);
    }

    FileView {
        id: legacyFile

        printErrors: false
        path: `${Paths.config}/widgets.json`
        watchChanges: false
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.legacyWidgets = Array.isArray(data) ? data : [];
            } catch (error) {
                root.legacyWidgets = [];
            }
            root.legacyReady = true;
        }
        onLoadFailed: error => {
            root.legacyWidgets = [];
            root.legacyReady = true;
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.UPower
import Caelestia.Config
import qs.components
import qs.services
import "../background"
import "faces"

ClippingRectangle {
    id: root

    required property var widget
    required property ShellScreen screen
    property bool preview: false

    implicitWidth: widget.wWidth ?? 250
    implicitHeight: widget.wHeight ?? 120
    width: implicitWidth
    height: implicitHeight
    clip: true
    opacity: widget.wOpacity ?? 1
    rotation: widget.wRotation ?? 0
    color: "transparent"
    radius: backgroundRadius

    function fitImageAspect(imageWidth: real, imageHeight: real): void {
        if (preview || widget.wType !== "image" || imageWidth <= 0 || imageHeight <= 0 || !screen)
            return;

        const safe = WidgetRegistry.safeArea(screen.width, screen.height, false, false);
        const ratio = imageWidth / imageHeight;
        const currentWidth = Math.max(30, Number(widget.wWidth ?? 300));
        let nextWidth;
        let nextHeight;

        if (widget.wVariant === "round") {
            nextWidth = nextHeight = Math.min(currentWidth, safe.width, safe.height);
        } else {
            nextWidth = Math.min(currentWidth, safe.width);
            nextHeight = nextWidth / ratio;
            if (nextHeight > safe.height) {
                nextHeight = safe.height;
                nextWidth = nextHeight * ratio;
            }
        }

        nextWidth = Math.max(30, Math.round(nextWidth));
        nextHeight = Math.max(30, Math.round(nextHeight));
        if (Math.abs(Number(widget.wWidth) - nextWidth) < 1 && Math.abs(Number(widget.wHeight) - nextHeight) < 1)
            return;

        WidgetsPrefs.updateWidgetFields(screen.name, widget.wId, {
            wWidth: nextWidth,
            wHeight: nextHeight
        });
    }

    readonly property real backgroundOpacity: {
        const opacity = Number(widget.wProps?.bgOpacity ?? 0.82);
        return Number.isFinite(opacity) ? Math.max(0, Math.min(1, opacity)) : 0.82;
    }
    readonly property real backgroundBorderWidth: {
        const width = Number(widget.wProps?.bgBorderWidth ?? 0);
        return Number.isFinite(width) ? Math.max(0, Math.min(100, width)) : 0;
    }
    readonly property real backgroundRadius: {
        const configured = Number(widget.wProps?.bgRadius);
        if (Number.isFinite(configured) && widget.wProps?.bgRadius !== undefined)
            return Math.max(0, Math.min(configured, Math.min(width, height) / 2));
        if (widget.wType === "image") {
            if (widget.wVariant === "round") return Math.min(width, height) / 2;
            if (widget.wVariant === "rounded") return Math.min(22, Math.min(width, height) / 2);
            return 0;
        }
        return ["round", "analog", "materialAnalog", "lumen"].includes(widget.wVariant) ? Math.min(width, height) / 2 : Tokens.rounding.large;
    }
    readonly property color backgroundStart: Qt.alpha(resolveBackgroundColor(widget.wProps?.bgColor, Colours.palette.m3surfaceContainer), backgroundOpacity)
    readonly property color backgroundEnd: Qt.alpha(resolveBackgroundColor(widget.wProps?.bgColor2, Colours.palette.m3primaryContainer), backgroundOpacity)
    readonly property color backgroundBorder: Qt.alpha(resolveBackgroundColor(widget.wProps?.bgBorderColor, Colours.palette.m3outlineVariant), backgroundOpacity)

    function resolveBackgroundColor(value: var, fallback: color): color {
        const key = String(value ?? "").trim().toLowerCase();
        if (key === "primary") return Colours.palette.m3primaryContainer;
        if (key === "secondary") return Colours.palette.m3secondaryContainer;
        if (key === "tertiary") return Colours.palette.m3tertiaryContainer;
        if (key === "surface") return Colours.palette.m3surfaceContainer;
        if (/^#[0-9a-f]{6}$/i.test(key)) return Qt.color(key);
        return fallback;
    }

    StyledRect {
        id: background
        anchors.fill: parent
        visible: root.widget.wProps?.bgVisible !== false
        radius: root.backgroundRadius
        color: root.backgroundStart
        clip: true
        gradient: root.widget.wProps?.bgGradient === true ? fillGradient : null

        Gradient {
            id: fillGradient
            GradientStop { position: 0; color: root.backgroundStart }
            GradientStop { position: 1; color: root.backgroundEnd }
        }
    }

    Loader {
        id: faceLoader
        anchors.fill: parent
        onLoaded: {
            if (item && "widget" in item) item.widget = root.widget;
            if (item && "screen" in item) item.screen = root.screen;
        }
        sourceComponent: {
            const registered = WidgetRegistry.get(root.widget.wType).component;
            if (registered) return registered;
            switch (root.widget.wType) {
            case "time":
            case "clock": return clockFace;
            case "calendar": return calendarFace;
            case "music":
            case "media": return musicFace;
            case "weather": return weatherFace;
            case "image": return imageFace;
            case "user": return userFace;
            case "cpu": return cpuFace;
            case "ram": return ramFace;
            case "temp": return tempFace;
            case "disk": return diskFace;
            case "battery": return batteryFace;
            case "workspace": return workspaceFace;
            case "network": return networkFace;
            case "note": return noteFace;
            case "github": return githubFace;
            case "visualizer": return visualizerFace;
            case "arch": return archFace;
            case "resources": return resourcesFace;
            default: return clockFace;
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        z: 10
        color: "transparent"
        radius: root.backgroundRadius
        border.width: root.backgroundBorderWidth
        border.color: root.backgroundBorder
        visible: root.backgroundBorderWidth > 0
        antialiasing: true
    }

    Connections {
        target: faceLoader.item
        ignoreUnknownSignals: true
        function onNaturalSizeChanged(imageWidth: real, imageHeight: real): void {
            root.fitImageAspect(imageWidth, imageHeight);
        }
    }

    Component {
        id: clockFace
        ClockWidget {
            variant: root.widget.wVariant ?? "digital"
            bgVisible: root.widget.wProps?.bgVisible ?? true
        }
    }
    Component {
        id: calendarFace
        CalendarFace { }
    }
    Component {
        id: musicFace
        MediaWidget {
            widget: root.widget
            variant: root.widget.wVariant ?? "full"
            bgVisible: root.widget.wProps?.bgVisible ?? true
            lyricsLines: Number(root.widget.wProps?.lyricsLines ?? 1)
            lyricsAlignment: root.widget.wProps?.lyricsAlignment ?? "left"
        }
    }
    Component {
        id: weatherFace
        WeatherWidget {
            variant: root.widget.wVariant ?? "compact"
            bgVisible: root.widget.wProps?.bgVisible ?? true
        }
    }
    Component { id: imageFace; ImageFace { widget: root.widget } }
    Component { id: userFace; UserFace { widget: root.widget } }
    Component { id: cpuFace; MetricFace { widget: root.widget; metric: "cpu" } }
    Component { id: ramFace; MetricFace { widget: root.widget; metric: "ram" } }
    Component { id: tempFace; MetricFace { widget: root.widget; metric: "temp" } }
    Component { id: diskFace; MetricFace { widget: root.widget; metric: "disk" } }
    Component { id: batteryFace; BatteryFace { widget: root.widget } }
    Component { id: workspaceFace; WorkspaceFace { widget: root.widget; screen: root.screen } }
    Component { id: networkFace; NetworkFace { widget: root.widget } }
    Component { id: noteFace; NoteFace { widget: root.widget; screen: root.screen } }
    Component { id: githubFace; GithubFace { widget: root.widget } }
    Component { id: visualizerFace; VisualizerFace { widget: root.widget } }
    Component {
        id: archFace
        ArchWidget { }
    }
    Component {
        id: resourcesFace
        ResourcesWidget { bgVisible: root.widget.wProps?.bgVisible ?? true }
    }
}

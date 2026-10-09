pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

StyledRect {
    id: root

    required property string screenName
    required property ShellScreen screen
    property var selectedIds: []
    property bool aspectLock: false
    readonly property var widgets: WidgetsPrefs.layoutFor(screenName)
    readonly property var selected: widgets.find(item => String(item.wId) === String(selectedIds.length ? selectedIds[selectedIds.length - 1] : "")) ?? null
    onSelectedChanged: syncInspectorFields()

    signal selectionRequested(string id, bool additive)
    signal propertyEdited(string id, string key, var value)
    signal variantRequested(string id, string variant)
    signal anchorRequested(string id, string horizontal, string vertical)
    signal aspectLockRequested(bool locked)
    signal resetSizeRequested(string id)
    signal removeRequested(string id)
    signal orderRequested(string id, int direction)

    radius: Tokens.rounding.large
    color: Colours.palette.m3surfaceContainer
    clip: true

    function edit(key: string, value: var): void {
        if (selected) propertyEdited(String(selected.wId), key, value);
    }

    function applyImagePath(): void {
        if (!selected || selected.wType !== "image") return;
        const path = WidgetsPrefs.normalizeImagePath(imagePathInput.draftPath);
        edit("wImagePath", path);
        imagePathInput.draftPath = path;
        imagePathInput.text = path;
    }

    function syncInspectorFields(): void {
        if (!imagePathInput.activeFocus) {
            imagePathInput.draftPath = selected?.wType === "image" ? String(selected.wImagePath ?? "") : "";
            imagePathInput.text = imagePathInput.draftPath;
        }
        if (!radiusInput.activeFocus) radiusInput.text = String(Math.round(Number(selected?.wProps?.bgRadius ?? defaultRadius())));
        if (!borderWidthInput.activeFocus) borderWidthInput.text = String(Math.round(Number(selected?.wProps?.bgBorderWidth ?? 0)));
    }

    function defaultRadius(): real {
        if (!selected) return Tokens.rounding.large;
        const size = WidgetRegistry.sizeFor(selected, screen.width, screen.height);
        if (selected.wType === "image") {
            if (selected.wVariant === "round") return Math.min(size.width, size.height) / 2;
            if (selected.wVariant === "rounded") return Math.min(22, Math.min(size.width, size.height) / 2);
            return 0;
        }
        return ["round", "analog", "materialAnalog", "lumen"].includes(selected.wVariant) ? Math.min(size.width, size.height) / 2 : Tokens.rounding.large;
    }

    Flickable {
        id: scroll
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        contentWidth: width
        contentHeight: inspectorContent.implicitHeight
        flickableDirection: Flickable.VerticalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        ColumnLayout {
            id: inspectorContent
            width: scroll.width
            spacing: Tokens.spacing.normal

            StyledText {
                Layout.fillWidth: true
                text: root.selected ? WidgetRegistry.get(root.selected.wType).name : qsTr("Widgets on desktop")
                color: Colours.palette.m3onSurface
                font.bold: true
                font.pointSize: Tokens.font.size.large
                elide: Text.ElideRight
            }

            Flow {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                Repeater {
                    model: root.widgets
                    delegate: TextButton {
                        required property var modelData
                        text: WidgetRegistry.get(modelData.wType).name
                        type: String(modelData.wId) === String(root.selected?.wId ?? "") ? TextButton.Filled : TextButton.Text
                        onClicked: root.selectionRequested(String(modelData.wId), false)
                    }
                }
            }

            StyledText { visible: !!root.selected; text: qsTr("Style"); color: Colours.palette.m3onSurfaceVariant }
            Flow {
                visible: !!root.selected
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                Repeater {
                    model: root.selected ? WidgetRegistry.get(root.selected.wType).variants : []
                    delegate: TextButton {
                        required property string modelData
                        text: modelData
                        type: modelData === root.selected?.wVariant ? TextButton.Filled : TextButton.Text
                        onClicked: if (root.selected) root.variantRequested(String(root.selected.wId), modelData)
                    }
                }
            }

            StyledText { visible: !!root.selected; text: qsTr("Opacity · %1%").arg(Math.round(Number(root.selected?.wOpacity ?? 1) * 100)); color: Colours.palette.m3onSurfaceVariant }
            StyledSlider {
                visible: !!root.selected
                Layout.fillWidth: true
                from: 0.15; to: 1
                value: Number(root.selected?.wOpacity ?? 1)
                onMoved: root.edit("wOpacity", value)
            }

            RowLayout {
                visible: !!root.selected
                StyledText { Layout.fillWidth: true; text: qsTr("Rotation"); color: Colours.palette.m3onSurfaceVariant }
                IconButton { icon: "rotate_left"; onClicked: if (root.selected) root.edit("wRotation", ((root.selected.wRotation ?? 0) + 270) % 360) }
                StyledText { text: `${root.selected?.wRotation ?? 0}°`; color: Colours.palette.m3onSurface }
                IconButton { icon: "rotate_right"; onClicked: if (root.selected) root.edit("wRotation", ((root.selected.wRotation ?? 0) + 90) % 360) }
                IconButton { icon: "restart_alt"; onClicked: root.edit("wRotation", 0) }
            }

            RowLayout {
                visible: !!root.selected
                StyledText { Layout.fillWidth: true; text: qsTr("Lock aspect ratio"); color: Colours.palette.m3onSurfaceVariant }
                Switch { checked: root.aspectLock; onToggled: root.aspectLockRequested(checked) }
            }

            GridLayout {
                visible: !!root.selected
                Layout.alignment: Qt.AlignHCenter
                columns: 3
                Repeater {
                    model: [
                        { h: "left", v: "top", label: "↖" }, { h: "center", v: "top", label: "↑" }, { h: "right", v: "top", label: "↗" },
                        { h: "left", v: "center", label: "←" }, { h: "center", v: "center", label: "•" }, { h: "right", v: "center", label: "→" },
                        { h: "left", v: "bottom", label: "↙" }, { h: "center", v: "bottom", label: "↓" }, { h: "right", v: "bottom", label: "↘" }
                    ]
                    delegate: StyledRect {
                        required property var modelData
                        Layout.preferredWidth: 38; Layout.preferredHeight: 32
                        radius: Tokens.rounding.small
                        color: root.selected?.anchorH === modelData.h && root.selected?.anchorV === modelData.v ? Colours.palette.m3primaryContainer : Colours.palette.m3surface
                        StyledText { anchors.centerIn: parent; text: parent.modelData.label; color: Colours.palette.m3onSurface }
                        StateLayer { radius: parent.radius; onClicked: if (root.selected) root.anchorRequested(String(root.selected.wId), parent.modelData.h, parent.modelData.v) }
                    }
                }
            }

            RowLayout {
                visible: !!root.selected
                StyledText { Layout.fillWidth: true; text: qsTr("Background"); color: Colours.palette.m3onSurface; font.bold: true }
                Switch { checked: root.selected?.wProps?.bgVisible !== false; onToggled: root.edit("bgVisible", checked) }
            }

            WidgetColorPicker {
                visible: !!root.selected && root.selected?.wProps?.bgVisible !== false
                Layout.fillWidth: true
                title: qsTr("Fill color")
                value: String(root.selected?.wProps?.bgColor ?? "")
                fallback: Colours.palette.m3surfaceContainer
                onColorSelected: value => root.edit("bgColor", value)
            }

            RowLayout {
                visible: !!root.selected && root.selected?.wProps?.bgVisible !== false
                StyledText { Layout.fillWidth: true; text: qsTr("Gradient"); color: Colours.palette.m3onSurfaceVariant }
                Switch { checked: root.selected?.wProps?.bgGradient === true; onToggled: root.edit("bgGradient", checked) }
            }
            WidgetColorPicker {
                visible: !!root.selected && root.selected?.wProps?.bgVisible !== false && root.selected?.wProps?.bgGradient === true
                Layout.fillWidth: true
                title: qsTr("Gradient color")
                value: String(root.selected?.wProps?.bgColor2 ?? "primary")
                fallback: Colours.palette.m3primaryContainer
                onColorSelected: value => root.edit("bgColor2", value)
            }

            StyledText { visible: !!root.selected && root.selected?.wProps?.bgVisible !== false; text: qsTr("Opacity · %1%").arg(Math.round(Number(root.selected?.wProps?.bgOpacity ?? 0.82) * 100)); color: Colours.palette.m3onSurfaceVariant }
            StyledSlider { visible: !!root.selected && root.selected?.wProps?.bgVisible !== false; Layout.fillWidth: true; from: 0; to: 1; value: Number(root.selected?.wProps?.bgOpacity ?? 0.82); onMoved: root.edit("bgOpacity", value) }
            StyledText { visible: !!root.selected; text: qsTr("Corner radius · %1 px").arg(Math.round(Number(root.selected?.wProps?.bgRadius ?? root.defaultRadius()))); color: Colours.palette.m3onSurfaceVariant }
            StyledSlider { visible: !!root.selected; Layout.fillWidth: true; from: 0; to: Math.max(1, Math.min(root.selected ? WidgetRegistry.sizeFor(root.selected, root.screen.width, root.screen.height).width : 1, root.selected ? WidgetRegistry.sizeFor(root.selected, root.screen.width, root.screen.height).height : 1) / 2); value: Number(root.selected?.wProps?.bgRadius ?? root.defaultRadius()); onMoved: root.edit("bgRadius", value) }
            StyledText { visible: !!root.selected; text: qsTr("Border · %1 px").arg(Number(root.selected?.wProps?.bgBorderWidth ?? 0)); color: Colours.palette.m3onSurfaceVariant }
            StyledSlider { visible: !!root.selected; Layout.fillWidth: true; from: 0; to: 8; value: Number(root.selected?.wProps?.bgBorderWidth ?? 0); onMoved: root.edit("bgBorderWidth", Math.round(value)) }
            WidgetColorPicker {
                visible: !!root.selected && Number(root.selected?.wProps?.bgBorderWidth ?? 0) > 0
                Layout.fillWidth: true
                title: qsTr("Border color")
                value: String(root.selected?.wProps?.bgBorderColor ?? "")
                fallback: Colours.palette.m3outlineVariant
                onColorSelected: value => root.edit("bgBorderColor", value)
            }

            WidgetColorPicker {
                visible: root.selected?.wType === "github"
                Layout.fillWidth: true
                title: qsTr("GitHub text color")
                value: String(root.selected?.wProps?.textColor ?? "")
                fallback: Colours.palette.m3onSurface
                onColorSelected: value => root.edit("textColor", value)
            }

            StyledText { visible: root.selected?.wType === "music"; text: qsTr("Music player"); color: Colours.palette.m3onSurfaceVariant }
            Flow {
                visible: root.selected?.wType === "music"
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                Repeater {
                    model: [{ identity: "", label: qsTr("Follow active") }].concat(Players.list.map(player => ({ identity: Players.getIdentity(player), label: Players.getIdentity(player) })))
                    delegate: TextButton {
                        required property var modelData
                        text: modelData.label
                        type: String(root.selected?.wProps?.playerIdentity ?? "") === modelData.identity ? TextButton.Filled : TextButton.Text
                        onClicked: root.edit("playerIdentity", modelData.identity)
                    }
                }
            }
            WidgetColorPicker {
                visible: root.selected?.wType === "music"
                Layout.fillWidth: true
                title: qsTr("Text color")
                value: String(root.selected?.wProps?.textColor ?? "")
                fallback: Colours.palette.m3onSurface
                onColorSelected: value => root.edit("textColor", value)
            }
            WidgetColorPicker {
                visible: root.selected?.wType === "music"
                Layout.fillWidth: true
                title: qsTr("Accent color")
                value: String(root.selected?.wProps?.accentColor ?? "")
                fallback: Colours.palette.m3primary
                onColorSelected: value => root.edit("accentColor", value)
            }
            RowLayout {
                visible: root.selected?.wType === "music"
                StyledText { Layout.fillWidth: true; text: qsTr("Album artwork"); color: Colours.palette.m3onSurfaceVariant }
                Switch { checked: root.selected?.wProps?.showAlbumArt !== false; onToggled: root.edit("showAlbumArt", checked) }
            }
            RowLayout {
                visible: root.selected?.wType === "music"
                StyledText { Layout.fillWidth: true; text: qsTr("Playback controls"); color: Colours.palette.m3onSurfaceVariant }
                Switch { checked: root.selected?.wProps?.showControls !== false; onToggled: root.edit("showControls", checked) }
            }
            RowLayout {
                visible: root.selected?.wType === "music" && root.selected?.wVariant === "full"
                StyledText { Layout.fillWidth: true; text: qsTr("Progress bar"); color: Colours.palette.m3onSurfaceVariant }
                Switch { checked: root.selected?.wProps?.showProgress !== false; onToggled: root.edit("showProgress", checked) }
            }
            RowLayout {
                visible: root.selected?.wType === "music" && ["full", "round"].includes(root.selected?.wVariant)
                StyledText { Layout.fillWidth: true; text: qsTr("Audio spectrum"); color: Colours.palette.m3onSurfaceVariant }
                Switch { checked: root.selected?.wProps?.showVisualizer !== false; onToggled: root.edit("showVisualizer", checked) }
            }

            StyledText { visible: root.selected?.wType === "music" && ["lyrics", "simpleLyrics"].includes(root.selected?.wVariant); text: qsTr("Lyrics alignment"); color: Colours.palette.m3onSurfaceVariant }
            Flow {
                visible: root.selected?.wType === "music" && ["lyrics", "simpleLyrics"].includes(root.selected?.wVariant)
                Layout.fillWidth: true; spacing: Tokens.spacing.small
                Repeater {
                    model: ["left", "center", "right"]
                    delegate: TextButton { required property string modelData; text: modelData; type: (root.selected?.wProps?.lyricsAlignment ?? "left") === modelData ? TextButton.Filled : TextButton.Text; onClicked: root.edit("lyricsAlignment", modelData) }
                }
            }
            RowLayout {
                visible: root.selected?.wType === "music" && root.selected?.wVariant === "simpleLyrics"
                StyledText { Layout.fillWidth: true; text: qsTr("Lines"); color: Colours.palette.m3onSurfaceVariant }
                IconButton { icon: "remove"; onClicked: root.edit("lyricsLines", Math.max(0, Number(root.selected?.wProps?.lyricsLines ?? 1) - 1)) }
                StyledText { text: String(root.selected?.wProps?.lyricsLines ?? 1); color: Colours.palette.m3onSurface }
                IconButton { icon: "add"; onClicked: root.edit("lyricsLines", Math.min(4, Number(root.selected?.wProps?.lyricsLines ?? 1) + 1)) }
            }

            RowLayout {
                visible: !!root.selected
                TextButton { Layout.fillWidth: true; text: qsTr("Send backward"); onClicked: if (root.selected) root.orderRequested(String(root.selected.wId), -1) }
                TextButton { Layout.fillWidth: true; text: qsTr("Bring forward"); onClicked: if (root.selected) root.orderRequested(String(root.selected.wId), 1) }
            }
            RowLayout {
                visible: !!root.selected
                TextButton { Layout.fillWidth: true; text: qsTr("Reset size"); onClicked: if (root.selected) root.resetSizeRequested(String(root.selected.wId)) }
                TextButton { Layout.fillWidth: true; visible: root.selected?.wType === "visualizer"; text: root.selected?.wProps?.stretchWidth ? qsTr("Fixed width") : qsTr("Stretch width"); onClicked: root.edit("stretchWidth", !root.selected?.wProps?.stretchWidth) }
            }

            StyledText { visible: root.selected?.wType === "github"; text: qsTr("GitHub username"); color: Colours.palette.m3onSurfaceVariant }
            StyledInputField { visible: root.selected?.wType === "github"; Layout.fillWidth: true; text: root.selected?.wProps?.username ?? ""; onTextEdited: text => root.edit("username", text) }
            StyledText { visible: root.selected?.wType === "user"; text: qsTr("Display name"); color: Colours.palette.m3onSurfaceVariant }
            StyledInputField { visible: root.selected?.wType === "user"; Layout.fillWidth: true; text: root.selected?.wProps?.displayName ?? ""; onTextEdited: text => root.edit("displayName", text) }
            StyledText { visible: root.selected?.wType === "image"; text: qsTr("Image file path"); color: Colours.palette.m3onSurfaceVariant }
            RowLayout {
                visible: root.selected?.wType === "image"
                Layout.fillWidth: true

                TextField {
                    id: imagePathInput
                    Layout.fillWidth: true
                    property string draftPath: ""
                    placeholderText: qsTr("/home/…/image.png")
                    color: Colours.palette.m3onSurfaceVariant
                    placeholderTextColor: Colours.palette.m3outline
                    onTextChanged: if (activeFocus) draftPath = text
                    onAccepted: root.applyImagePath()
                    onActiveFocusChanged: if (!activeFocus) root.syncInspectorFields()
                    Component.onCompleted: root.syncInspectorFields()
                }

                TextButton {
                    text: qsTr("Apply")
                    onClicked: root.applyImagePath()
                }
            }
            StyledText { visible: root.selected?.wType === "image"; Layout.fillWidth: true; text: qsTr("Paste an image path and press Enter to apply it."); color: Colours.palette.m3onSurfaceVariant; wrapMode: Text.WordWrap }
            RowLayout {
                visible: !!root.selected
                Layout.fillWidth: true
                StyledText { Layout.fillWidth: true; text: qsTr("Radius (px)"); color: Colours.palette.m3onSurfaceVariant }
                TextField {
                    id: radiusInput
                    Layout.preferredWidth: 88
                    property string draft: "0"
                    color: Colours.palette.m3onSurface
                    validator: IntValidator { bottom: 0; top: 2000 }
                    onTextChanged: if (activeFocus) draft = text
                    onAccepted: {
                        const radius = Math.max(0, Number(draft) || 0);
                        root.edit("bgRadius", radius);
                        draft = String(radius); text = draft;
                    }
                    onActiveFocusChanged: if (!activeFocus) root.syncInspectorFields()
                    Component.onCompleted: root.syncInspectorFields()
                }
            }
            RowLayout {
                visible: !!root.selected
                Layout.fillWidth: true
                StyledText { Layout.fillWidth: true; text: qsTr("Border (px)"); color: Colours.palette.m3onSurfaceVariant }
                TextField {
                    id: borderWidthInput
                    Layout.preferredWidth: 88
                    property string draft: "0"
                    color: Colours.palette.m3onSurface
                    validator: IntValidator { bottom: 0; top: 100 }
                    onTextChanged: if (activeFocus) draft = text
                    onAccepted: {
                        const borderWidth = Math.max(0, Number(draft) || 0);
                        root.edit("bgBorderWidth", borderWidth);
                        draft = String(borderWidth); text = draft;
                    }
                    onActiveFocusChanged: if (!activeFocus) root.syncInspectorFields()
                    Component.onCompleted: root.syncInspectorFields()
                }
            }
            TextButton { visible: !!root.selected; text: qsTr("Remove widget"); onClicked: if (root.selected) root.removeRequested(String(root.selected.wId)) }
        }
    }
}

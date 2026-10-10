pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.components.images
import qs.utils
import qs.services

Item {
    id: root
    required property ShellScreen screen
    property bool fullscreen: false
    property bool running: true
    property bool focusMode: false
    readonly property var canvasItem: fullscreen ? fullscreenCanvas.item : canvasLoader.item
    property var selectedIds: []
    property bool gridSnap: false
    property bool aspectLock: false
    property string preset: ""
    property string imageTarget: ""
    readonly property string screenName: screen?.name ?? ""
    readonly property bool ready: !!screen && WidgetsPrefs.isReady(screenName)
    readonly property bool wide: fullscreen || width >= 900
    readonly property var widgets: WidgetsPrefs.layoutFor(screenName)
    readonly property var previewLayout: preset ? WidgetPresets.layout(preset, screen) : widgets
    readonly property var safe: screen ? WidgetRegistry.safeArea(screen.width, screen.height, false, false) : ({
            x: 0,
            y: 0,
            width: 1,
            height: 1
        })
    signal fullscreenRequested
    signal closeRequested
    clip: true
    onScreenNameChanged: {
        selectedIds = [];
        preset = "";
    }
    onWidgetsChanged: selectedIds = selectedIds.filter(id => widgets.some(w => String(w.wId) === id))

    function selectWidget(id: string, additive: bool): void {
        let ids = additive ? selectedIds.slice() : [];
        const index = ids.indexOf(String(id));
        if (index >= 0)
            ids.splice(index, 1);
        else
            ids.push(String(id));
        selectedIds = ids;
    }
    function commitGeometry(entries: var): void {
        if (!ready || preset)
            return;
        const layout = JSON.parse(JSON.stringify(widgets));
        for (const entry of entries) {
            const item = layout.find(w => String(w.wId) === String(entry.id));
            if (!item)
                continue;
            const size = WidgetRegistry.constrainSize(item.wType, item.wVariant, entry.width, entry.height, false);
            const fit = Math.min(1, safe.width / size.w, safe.height / size.h);
            const w = Math.round(size.w * fit), h = Math.round(size.h * fit);
            const x = Math.max(safe.x, Math.min(entry.x, safe.x + safe.width - w));
            const y = Math.max(safe.y, Math.min(entry.y, safe.y + safe.height - h));
            Object.assign(item, WidgetsPrefs.storedPosition(screenName, x, y), {
                wWidth: Math.round(w),
                wHeight: Math.round(h),
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
                anchorVertical: "",
                stretchWidth: false,
                stretchHeight: false,
                wStretchWidth: false,
                wStretchHeight: false
            });
            item.wProps = Object.assign({}, item.wProps ?? {}, {
                stretchWidth: false,
                stretchHeight: false
            });
        }
        WidgetsPrefs.setLayout(screenName, layout);
    }
    function edit(id: string, key: string, value: var): void {
        if (!ready || preset)
            return;
        if (["wOpacity", "wRotation", "wImagePath", "enabled"].includes(key))
            WidgetsPrefs.updateWidget(screenName, id, key, key === "wImagePath" ? WidgetsPrefs.normalizeImagePath(value) : value);
        else
            WidgetsPrefs.updateWidgetProperty(screenName, id, key, value);
    }
    function geometryEdit(id: string, key: string, value: real): void {
        const item = widgets.find(w => String(w.wId) === id);
        if (!item)
            return;
        const position = WidgetRegistry.positionFor(item, screen.width, screen.height);
        const size = WidgetRegistry.sizeFor(item, screen.width, screen.height);
        const entry = {
            id: id,
            x: position.x,
            y: position.y,
            width: size.width,
            height: size.height
        };
        entry[key] = value;
        if (aspectLock && ["width", "height"].includes(key)) {
            const ratio = size.width / Math.max(1, size.height);
            if (key === "width")
                entry.height = value / ratio;
            else
                entry.width = value * ratio;
        }
        commitGeometry([entry]);
    }
    function add(type: string): void {
        if (!ready || preset)
            return;
        const id = WidgetsPrefs.addWidget(screenName, type, screen.width, screen.height);
        if (id) {
            selectedIds = [id];
            root.canvasItem?.forceActiveFocus();
        }
    }
    function removeSelected(): void {
        if (preset || !selectedIds.length)
            return;
        WidgetsPrefs.setLayout(screenName, widgets.filter(w => !selectedIds.includes(String(w.wId))));
    }

    Image {
        anchors.fill: parent
        visible: root.fullscreen
        source: /\.(mp4|mkv|webm|avi|mov)$/i.test(Wallpapers.actualCurrent) ? Wallpapers.thumbPath(Wallpapers.actualCurrent) : Wallpapers.actualCurrent
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
    }
    Loader {
        id: fullscreenCanvas
        onLoaded: item.forceActiveFocus()
        x: root.safe.x
        y: root.safe.y
        width: root.safe.width
        height: root.safe.height
        active: root.fullscreen && root.running && root.ready
        sourceComponent: canvasComponent
    }
    Rectangle {
        visible: root.fullscreen && !root.focusMode
        x: 12
        y: 12
        width: parent.width - 24
        height: 96
        radius: 16
        color: Qt.alpha(Colours.palette.m3surface, 0.96)
        border.width: 1
        border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.55)
    }
    ColumnLayout {
        z: 1
        visible: !root.focusMode
        anchors.fill: parent
        anchors.margins: root.fullscreen ? 24 : 0
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                Layout.fillWidth: true
                text: root.preset ? qsTr("Preview · %1").arg(root.preset) : root.fullscreen ? qsTr("Arrange your desktop") : qsTr("Your desktop, your composition")
                font.pointSize: Tokens.font.size.large
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Action {
                icon: "undo"
                hint: qsTr("Undo · Ctrl+Z")
                disabled: !WidgetsPrefs.canUndo(root.screenName) || !!root.preset
                onClicked: WidgetsPrefs.undo(root.screenName)
            }
            Action {
                icon: "redo"
                hint: qsTr("Redo · Ctrl+Shift+Z")
                disabled: !WidgetsPrefs.canRedo(root.screenName) || !!root.preset
                onClicked: WidgetsPrefs.redo(root.screenName)
            }
            Action {
                icon: root.gridSnap ? "grid_on" : "grid_off"
                hint: qsTr("Snap to grid")
                checked: root.gridSnap
                disabled: !!root.preset
                onClicked: root.gridSnap = !root.gridSnap
            }
            Action {
                visible: root.fullscreen
                icon: "visibility_off"
                hint: qsTr("Hide tools · F6")
                onClicked: {
                    root.focusMode = true;
                    root.canvasItem?.forceActiveFocus();
                }
            }
            Action {
                icon: root.fullscreen ? "close" : "open_in_full"
                hint: root.fullscreen ? qsTr("Close editor · Esc") : qsTr("Open full screen")
                onClicked: root.fullscreen ? root.closeRequested() : root.fullscreenRequested()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StyledText {
                Layout.fillWidth: true
                text: root.screen ? `${root.screenName}  ·  ${root.screen.width} × ${root.screen.height}` : qsTr("No display connected")
                font.pointSize: Tokens.font.size.small
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
            }
            StyledText {
                text: WidgetsPrefs.saveStates[root.screenName] === "loadError" ? qsTr("Could not load layout") : !root.ready ? qsTr("Loading…") : WidgetsPrefs.saveStates[root.screenName] === "error" ? qsTr("Could not save") : WidgetsPrefs.saveStates[root.screenName] === "saving" ? qsTr("Saving…") : qsTr("Saved locally")
                color: WidgetsPrefs.saveStates[root.screenName] === "error" ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
            }
            TextButton {
                visible: ["error", "loadError"].includes(WidgetsPrefs.saveStates[root.screenName])
                text: qsTr("Retry")
                type: TextButton.Text
                onClicked: WidgetsPrefs.retrySave(root.screenName)
            }
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: root.wide ? 2 : 1
            rowSpacing: 12
            columnSpacing: 12
            Rectangle {
                id: stage
                visible: !root.fullscreen
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 180
                Layout.preferredHeight: root.wide ? 400 : Math.max(180, root.height * 0.43)
                radius: 16
                color: Colours.palette.m3surfaceContainerLow
                border.width: 1
                border.color: Qt.alpha(Colours.palette.m3outlineVariant, 0.7)
                clip: true
                Item {
                    id: viewport
                    anchors.fill: parent
                    anchors.margins: 14
                    readonly property real factor: root.screen ? Math.max(0.001, Math.min(width / root.screen.width, height / root.screen.height)) : 1
                    Item {
                        id: desktop
                        width: root.screen?.width ?? 1
                        height: root.screen?.height ?? 1
                        x: (viewport.width - width * viewport.factor) / 2
                        y: (viewport.height - height * viewport.factor) / 2
                        scale: viewport.factor
                        transformOrigin: Item.TopLeft
                        Rectangle {
                            anchors.fill: parent
                            color: Colours.palette.m3surfaceContainer
                        }
                        Image {
                            anchors.fill: parent
                            source: /\.(mp4|mkv|webm|avi|mov)$/i.test(Wallpapers.actualCurrent) ? Wallpapers.thumbPath(Wallpapers.actualCurrent) : Wallpapers.actualCurrent
                            asynchronous: true
                            sourceSize.width: Math.round(viewport.width * 1.5)
                            fillMode: Image.PreserveAspectCrop
                        }
                        Loader {
                            id: canvasLoader
                            x: root.safe.x
                            y: root.safe.y
                            width: root.safe.width
                            height: root.safe.height
                            active: root.running && root.ready && !root.fullscreen
                            sourceComponent: canvasComponent
                        }
                    }
                }
                StyledText {
                    anchors.centerIn: parent
                    width: Math.min(300, parent.width - 40)
                    visible: !root.ready || root.previewLayout.length === 0
                    text: root.ready ? qsTr("Start with a preset below, or add your first widget.") : WidgetsPrefs.saveStates[root.screenName] === "loadError" ? qsTr("Your layout could not be loaded. Retry to keep your saved widgets safe.") : qsTr("Preparing your desktop…")
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    padding: 16
                    color: Colours.palette.m3onSurface
                    style: Text.Outline
                    styleColor: Colours.palette.m3surface
                }
            }
            Item {
                visible: root.fullscreen
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
            WidgetEditorInspector {
                Layout.preferredWidth: root.fullscreen ? 320 : root.wide ? 290 : -1
                Layout.fillWidth: !root.wide
                Layout.fillHeight: true
                Layout.minimumHeight: 140
                Layout.preferredHeight: root.wide ? 400 : 190
                screen: root.screen
                screenName: root.screenName
                selectedIds: root.selectedIds
                aspectLock: root.aspectLock
                enabled: root.ready && !root.preset
                onSelectionRequested: (id, additive) => root.selectWidget(id, additive)
                onPropertyEdited: (id, key, value) => root.edit(id, key, value)
                onGeometryEdited: (id, key, value) => root.geometryEdit(id, key, value)
                onVariantRequested: (id, variant) => WidgetsPrefs.setVariant(root.screenName, id, variant)
                onAnchorRequested: (id, horizontal, vertical) => {
                    const item = root.widgets.find(w => String(w.wId) === id);
                    if (!item)
                        return;
                    const position = WidgetRegistry.positionFor(item, root.screen.width, root.screen.height);
                    const size = WidgetRegistry.sizeFor(item, root.screen.width, root.screen.height);
                    WidgetsPrefs.setWidgetAnchor(root.screenName, id, horizontal, vertical, position.x, position.y, size.width, size.height, root.screen.width, root.screen.height);
                }
                onAspectLockRequested: locked => root.aspectLock = locked
                onResetSizeRequested: id => {
                    const item = root.widgets.find(w => String(w.wId) === id);
                    if (!item)
                        return;
                    const position = WidgetRegistry.positionFor(item, root.screen.width, root.screen.height);
                    const size = WidgetRegistry.sizeForVariant(item.wType, item.wVariant);
                    root.commitGeometry([
                        {
                            id: id,
                            x: position.x,
                            y: position.y,
                            width: size[0],
                            height: size[1]
                        }
                    ]);
                }
                onRemoveRequested: id => WidgetsPrefs.removeWidget(root.screenName, id)
                onOrderRequested: (id, direction) => WidgetsPrefs.moveWidget(root.screenName, id, direction)
                onImageBrowseRequested: id => {
                    root.imageTarget = id;
                    imagePicker.open();
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: !root.preset
            spacing: 4
            StyledText {
                Layout.fillWidth: true
                text: root.selectedIds.length ? qsTr("%1 selected").arg(root.selectedIds.length) : qsTr("Drag to arrange · Ctrl+click to select more")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                elide: Text.ElideRight
            }
            Action {
                icon: "grid_view"
                hint: qsTr("Arrange in a grid")
                disabled: !root.widgets.length
                onClicked: root.canvasItem?.arrange("grid")
            }
            Action {
                icon: "view_week"
                hint: qsTr("Arrange in a row")
                disabled: !root.widgets.length
                onClicked: root.canvasItem?.arrange("row")
            }
            Action {
                icon: "view_agenda"
                hint: qsTr("Arrange in a column")
                disabled: !root.widgets.length
                onClicked: root.canvasItem?.arrange("column")
            }
            Action {
                icon: "format_align_left"
                hint: qsTr("Align left")
                disabled: root.selectedIds.length < 2
                onClicked: root.canvasItem?.arrange("alignLeft")
            }
            Action {
                icon: "align_horizontal_center"
                hint: qsTr("Center horizontally")
                disabled: root.selectedIds.length < 2
                onClicked: root.canvasItem?.arrange("alignCenter")
            }
            Action {
                icon: "horizontal_distribute"
                hint: qsTr("Distribute horizontally")
                disabled: root.selectedIds.length < 3
                onClicked: root.canvasItem?.arrange("distributeHorizontal")
            }
            Action {
                id: moreLayout
                icon: "more_horiz"
                hint: qsTr("More alignment options")
                disabled: !root.widgets.length
                onClicked: {
                    const point = mapToItem(Controls.Overlay.overlay, 0, 0);
                    alignmentMenu.x = Math.max(8, Math.min(point.x, root.width - alignmentMenu.width - 8));
                    alignmentMenu.y = Math.max(8, point.y - alignmentMenu.implicitHeight - 8);
                    alignmentMenu.open();
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            StyledText {
                visible: root.width >= 680
                text: qsTr("Start with a composition")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
            }
            Repeater {
                model: ["Calm", "Studio", "Monitor"]
                TextButton {
                    required property string modelData
                    text: modelData
                    enabled: root.ready
                    type: root.preset === modelData ? TextButton.Filled : TextButton.Tonal
                    onClicked: {
                        root.preset = root.preset === modelData ? "" : modelData;
                        root.selectedIds = [];
                    }
                }
            }
            Item {
                Layout.fillWidth: true
            }
            TextButton {
                visible: !!root.preset
                text: qsTr("Cancel")
                type: TextButton.Text
                onClicked: root.preset = ""
            }
            TextButton {
                visible: !!root.preset
                text: qsTr("Use preset")
                onClicked: root.widgets.length ? presetDialog.open() : root.applyPreset()
            }
        }
        WidgetEditorGallery {
            Layout.fillWidth: true
            Layout.preferredHeight: root.height < 660 ? 100 : 120
            screenName: root.screenName
            screen: root.screen
            running: root.running && !root.preset
            enabled: root.ready && !root.preset
            onAddRequested: type => root.add(type)
        }
    }
    TextButton {
        z: 1
        visible: root.fullscreen && root.focusMode
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 20
        text: qsTr("Show tools · F6")
        type: TextButton.Tonal
        onClicked: root.focusMode = false
    }
    Controls.Menu {
        id: alignmentMenu
        width: 240
        background: Rectangle {
            color: Colours.palette.m3surfaceContainerHigh
            radius: 12
            border.width: 1
            border.color: Colours.palette.m3outlineVariant
        }
        Repeater {
            model: [
                {
                    label: qsTr("Align right"),
                    mode: "alignRight",
                    count: 2
                },
                {
                    label: qsTr("Align top"),
                    mode: "alignTop",
                    count: 2
                },
                {
                    label: qsTr("Center vertically"),
                    mode: "alignMiddle",
                    count: 2
                },
                {
                    label: qsTr("Align bottom"),
                    mode: "alignBottom",
                    count: 2
                },
                {
                    label: qsTr("Distribute vertically"),
                    mode: "distributeVertical",
                    count: 3
                },
                {
                    label: qsTr("Select all widgets"),
                    mode: "selectAll",
                    count: 0
                },
                {
                    label: qsTr("Clear selection"),
                    mode: "clearSelection",
                    count: 1
                }
            ]
            Controls.MenuItem {
                required property var modelData
                text: modelData.label
                enabled: root.selectedIds.length >= modelData.count
                contentItem: StyledText {
                    text: parent.text
                    color: Colours.palette.m3onSurface
                    opacity: parent.enabled ? 1 : 0.45
                    font.pointSize: TokenConfig.appearance.fontSize.small
                }
                background: Rectangle {
                    radius: 8
                    color: parent.highlighted ? Colours.palette.m3secondaryContainer : "transparent"
                }
                onTriggered: root.canvasItem?.arrange(modelData.mode)
            }
        }
    }
    Shortcut {
        sequence: "F6"
        enabled: root.fullscreen && root.running
        onActivated: {
            root.focusMode = !root.focusMode;
            root.canvasItem?.forceActiveFocus();
        }
    }
    // Popups live above the workspace, outside clipped cards and canvas hosts.
    Dialog {
        id: presetDialog
        anchors.centerIn: parent
        width: Math.min(380, root.width - 24)
        height: 200
        modal: true
        title: qsTr("Replace this display’s widgets?")
        palette.window: Colours.palette.m3surfaceContainerHigh
        palette.windowText: Colours.palette.m3onSurface
        palette.text: Colours.palette.m3onSurface
        palette.button: Colours.palette.m3secondaryContainer
        palette.buttonText: Colours.palette.m3onSecondaryContainer
        background: Rectangle {
            radius: 16
            color: Colours.palette.m3surfaceContainerHigh
            border.width: 1
            border.color: Colours.palette.m3outlineVariant
        }
        standardButtons: Dialog.Apply | Dialog.Cancel
        contentItem: Label {
            text: qsTr("The selected composition replaces this display’s layout. You can restore it with Undo.")
            wrapMode: Text.WordWrap
        }
        onApplied: {
            root.applyPreset();
            close();
        }
    }
    function applyPreset(): void {
        if (!root.preset || !ready)
            return;
        WidgetsPrefs.setLayout(screenName, WidgetPresets.layout(preset, screen));
        preset = "";
        selectedIds = [];
    }
    FileDialog {
        id: imagePicker
        title: qsTr("Choose a widget image")
        filterLabel: qsTr("Image files")
        filters: Images.validImageExtensions
        onAccepted: path => {
            if (root.widgets.some(w => String(w.wId) === root.imageTarget))
                root.edit(root.imageTarget, "wImagePath", path);
            root.imageTarget = "";
        }
        onRejected: root.imageTarget = ""
    }
    Component {
        id: canvasComponent
        WidgetEditorCanvas {
            id: editorCanvas

            screen: root.screen
            desktopX: root.safe.x
            desktopY: root.safe.y
            viewScale: root.fullscreen ? 1 : viewport.factor
            widgetLayout: root.previewLayout
            selectedIds: root.selectedIds
            gridSnap: root.gridSnap
            aspectLock: root.aspectLock
            enabled: !root.preset
            focus: true
            onActivated: forceActiveFocus()
            onSelectionChanged: (ids, activeId) => root.selectedIds = ids
            onGeometryCommitted: entries => root.commitGeometry(entries)
            Keys.onPressed: event => {
                const control = !!(event.modifiers & Qt.ControlModifier);
                const shift = !!(event.modifiers & Qt.ShiftModifier);
                if (control && event.key === Qt.Key_Z) {
                    shift ? WidgetsPrefs.redo(root.screenName) : WidgetsPrefs.undo(root.screenName);
                } else if (control && event.key === Qt.Key_A)
                    selectAll();
                else if (event.key === Qt.Key_Delete)
                    root.removeSelected();
                else if (event.key === Qt.Key_Escape) {
                    if (root.fullscreen)
                        root.focusMode ? root.focusMode = false : root.closeRequested();
                    else
                        root.selectedIds = [];
                } else if (event.key === Qt.Key_F6 && root.fullscreen)
                    root.focusMode = !root.focusMode;
                else if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(event.key)) {
                    const amount = shift ? 10 : 1;
                    nudge(event.key === Qt.Key_Left ? -amount : event.key === Qt.Key_Right ? amount : 0, event.key === Qt.Key_Up ? -amount : event.key === Qt.Key_Down ? amount : 0);
                } else
                    return;
                event.accepted = true;
            }
        }
    }

    component Action: IconButton {
        property string hint
        type: IconButton.Text
        implicitWidth: 34
        implicitHeight: 34
        Accessible.name: hint
        WidgetTooltip {
            visible: parent.stateLayer.containsMouse || parent.activeFocus
            text: parent.hint
        }
    }
}

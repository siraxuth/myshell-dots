pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import qs.services

Scope {
    id: root

    Loader {
        active: WidgetEditorController.active

        sourceComponent: Component {
            PanelWindow {
                id: window

                readonly property ShellScreen targetScreen: Quickshell.screens.find(screen => screen.name === WidgetEditorController.screenName) ?? Quickshell.screens[0]
                property var selectedIds: WidgetEditorController.selectedWidgetId ? [WidgetEditorController.selectedWidgetId] : []
                property bool aspectLock: false
                property bool focusCanvas: false

                screen: targetScreen
                color: "transparent"
                implicitWidth: targetScreen?.width ?? 1280
                implicitHeight: targetScreen?.height ?? 720
                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true
                exclusionMode: ExclusionMode.Ignore
                focusable: true
                WlrLayershell.namespace: "caelestia-widget-editor"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

                function updateProperty(id: string, key: string, value: var): void {
                    if (key === "wImagePath")
                        WidgetsPrefs.updateWidget(targetScreen.name, id, key, WidgetsPrefs.normalizeImagePath(value));
                    else if (key === "wOpacity" || key === "wRotation")
                        WidgetsPrefs.updateWidget(targetScreen.name, id, key, value);
                    else
                        WidgetsPrefs.updateWidgetProperty(targetScreen.name, id, key, value);
                }

                function commitGeometry(geometry: var): void {
                    const layout = WidgetsPrefs.layoutFor(targetScreen.name).map(item => Object.assign({}, item));
                    for (const entry of geometry) {
                        const index = layout.findIndex(item => String(item.wId) === String(entry.id));
                        if (index < 0) continue;
                        const position = WidgetsPrefs.storedPosition(targetScreen.name, entry.x, entry.y);
                        Object.assign(layout[index], {
                            wX: position.wX,
                            wY: position.wY,
                            wWidth: Math.round(entry.width),
                            wHeight: Math.round(entry.height),
                            anchor: "", anchors: "", anchorH: "", anchorV: "", anchorX: "", anchorY: "",
                            horizontalAnchor: "", verticalAnchor: "", hAnchor: "", vAnchor: "", anchorHorizontal: "", anchorVertical: "",
                            stretchWidth: false,
                            stretchHeight: false
                        });
                        layout[index].wProps = Object.assign({}, layout[index].wProps ?? {}, { stretchWidth: false, stretchHeight: false });
                    }
                    WidgetsPrefs.setLayout(targetScreen.name, layout);
                }

                function addWidget(type: string): void {
                    const id = WidgetsPrefs.addWidget(targetScreen.name, type, targetScreen.width, targetScreen.height);
                    if (!id) return;
                    const item = WidgetsPrefs.layoutFor(targetScreen.name).find(entry => String(entry.wId) === id);
                    if (!item) return;
                    const size = WidgetRegistry.sizeFor(item, targetScreen.width, targetScreen.height);
                    const x = canvas.x + Math.max(8, (canvas.width - size.width) / 2);
                    const y = canvas.y + Math.max(8, (canvas.height - size.height) / 2);
                    WidgetsPrefs.setWidgetPosition(targetScreen.name, id, x, y, size.width, size.height);
                    selectWidget(id, false);
                }

                function selectWidget(id: string, additive: bool): void {
                    const key = String(id);
                    let ids = additive ? selectedIds.slice() : [];
                    const index = ids.indexOf(key);
                    if (additive && index >= 0) ids.splice(index, 1);
                    else ids.push(key);
                    selectedIds = ids;
                    WidgetEditorController.selectedWidgetId = ids.length ? ids[ids.length - 1] : "";
                }

                function setVariant(id: string, variant: string): void {
                    WidgetsPrefs.setVariant(targetScreen.name, id, variant);
                }

                function setAnchor(id: string, horizontal: string, vertical: string): void {
                    const item = WidgetsPrefs.layoutFor(targetScreen.name).find(entry => String(entry.wId) === id);
                    if (!item) return;
                    const position = WidgetRegistry.positionFor(item, targetScreen.width, targetScreen.height);
                    const size = WidgetRegistry.sizeFor(item, targetScreen.width, targetScreen.height);
                    WidgetsPrefs.setWidgetAnchor(targetScreen.name, id, horizontal, vertical, position.x, position.y, size.width, size.height, targetScreen.width, targetScreen.height);
                }

                function resetSize(id: string): void {
                    const item = WidgetsPrefs.layoutFor(targetScreen.name).find(entry => String(entry.wId) === id);
                    if (!item) return;
                    const position = WidgetRegistry.positionFor(item, targetScreen.width, targetScreen.height);
                    const size = WidgetRegistry.sizeForVariant(item.wType, item.wVariant);
                    WidgetsPrefs.setWidgetPosition(targetScreen.name, id, position.x, position.y, size[0], size[1]);
                }

                Rectangle { anchors.fill: parent; z: -2; color: "#88000000" }

                WidgetEditorToolbar {
                    id: toolbar
                    z: 1
                    visible: !window.focusCanvas
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Tokens.padding.large
                    screenName: targetScreen?.name ?? ""
                    screenSize: targetScreen ? `${Math.round(targetScreen.width)} × ${Math.round(targetScreen.height)}` : ""
                    focusMode: window.focusCanvas
                    onLayoutRequested: mode => canvas.arrange(mode)
                    onClearRequested: clearDialog.open()
                    onCloseRequested: WidgetEditorController.close()
                    onFocusModeRequested: window.focusCanvas = !window.focusCanvas
                }

                WidgetEditorGallery {
                    id: gallery
                    z: 1
                    visible: !window.focusCanvas
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: Tokens.padding.large
                    anchors.rightMargin: Tokens.padding.large
                    anchors.bottomMargin: Tokens.padding.large
                    screenName: targetScreen?.name ?? ""
                    onAddRequested: type => window.addWidget(type)
                }

                WidgetEditorInspector {
                    id: inspector
                    z: 99
                    visible: !window.focusCanvas
                    anchors.top: toolbar.bottom
                    anchors.right: parent.right
                    anchors.bottom: gallery.top
                    anchors.topMargin: Tokens.padding.large
                    anchors.rightMargin: Tokens.padding.large
                    anchors.bottomMargin: Tokens.padding.large
                    width: Math.min(380, Math.max(320, parent.width * 0.30))
                    screenName: targetScreen?.name ?? ""
                    screen: targetScreen
                    selectedIds: window.selectedIds
                    aspectLock: window.aspectLock
                    onSelectionRequested: (id, additive) => window.selectWidget(id, additive)
                    onPropertyEdited: (id, key, value) => window.updateProperty(id, key, value)
                    onVariantRequested: (id, variant) => window.setVariant(id, variant)
                    onAnchorRequested: (id, horizontal, vertical) => window.setAnchor(id, horizontal, vertical)
                    onAspectLockRequested: locked => window.aspectLock = locked
                    onResetSizeRequested: id => window.resetSize(id)
                    onRemoveRequested: id => {
                        WidgetsPrefs.removeWidget(targetScreen.name, id);
                        window.selectedIds = window.selectedIds.filter(selectedId => selectedId !== id);
                        WidgetEditorController.selectedWidgetId = window.selectedIds.length ? window.selectedIds[window.selectedIds.length - 1] : "";
                    }
                    onOrderRequested: (id, direction) => WidgetsPrefs.moveWidget(targetScreen.name, id, direction)
                }

                WidgetEditorCanvas {
                    id: canvas
                    z: -1
                    anchors.fill: parent
                    screen: targetScreen
                    selectedIds: window.selectedIds
                    gridSnap: toolbar.gridSnap
                    aspectLock: window.aspectLock
                    onSelectionChanged: (ids, activeId) => {
                        window.selectedIds = ids;
                        WidgetEditorController.selectedWidgetId = activeId;
                    }
                    onGeometryCommitted: geometry => window.commitGeometry(geometry)
                }

                Dialog {
                    id: clearDialog
                    modal: true
                    title: qsTr("Remove all desktop widgets?")
                    standardButtons: Dialog.Yes | Dialog.Cancel
                    onAccepted: {
                        WidgetsPrefs.clearWidgets(targetScreen.name);
                        window.selectedIds = [];
                        WidgetEditorController.selectedWidgetId = "";
                    }
                }

                Shortcut {
                    sequence: "Escape"
                    onActivated: WidgetEditorController.close()
                }
                Shortcut {
                    sequence: "Ctrl+A"
                    onActivated: canvas.selectAll()
                }
                Shortcut {
                    sequence: "F6"
                    onActivated: window.focusCanvas = !window.focusCanvas
                }
            }
        }
    }
}

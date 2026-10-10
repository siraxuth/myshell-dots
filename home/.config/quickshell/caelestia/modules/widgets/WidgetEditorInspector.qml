pragma ComponentBehavior: Bound
import QtQuick
import qs.modules.settings.components
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Rectangle {
    id: root
    required property string screenName
    required property ShellScreen screen
    property var selectedIds: []
    property bool aspectLock: false
    readonly property var widgets: WidgetsPrefs.layoutFor(screenName)
    onSelectedChanged: Qt.callLater(() => {
        if (scroller.contentItem && "contentY" in scroller.contentItem)
            scroller.contentItem.contentY = 0;
    })
    readonly property var selected: widgets.find(w => String(w.wId) === selectedIds[selectedIds.length - 1]) ?? null
    readonly property var size: selected && screen ? WidgetRegistry.sizeFor(selected, screen.width, screen.height) : ({
            width: 0,
            height: 0
        })
    readonly property var position: selected && screen ? WidgetRegistry.positionFor(selected, screen.width, screen.height) : ({
            x: 0,
            y: 0
        })
    signal selectionRequested(string id, bool additive)
    signal propertyEdited(string id, string key, var value)
    signal geometryEdited(string id, string key, real value)
    signal variantRequested(string id, string variant)
    signal anchorRequested(string id, string horizontal, string vertical)
    signal aspectLockRequested(bool locked)
    signal resetSizeRequested(string id)
    signal removeRequested(string id)
    signal orderRequested(string id, int direction)
    signal imageBrowseRequested(string id)
    color: Colours.palette.m3surfaceContainer
    radius: 16
    clip: true
    function edit(key: string, value: var): void {
        if (selected)
            propertyEdited(String(selected.wId), key, value);
    }

    ScrollView {
        id: scroller
        anchors.fill: parent
        anchors.margins: 16
        contentWidth: availableWidth
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical: SettingsScrollBar {
            flickable: scroller.contentItem
        }
        SettingsScrollHandler {
            flickable: scroller.contentItem
        }
        ColumnLayout {
            width: parent.width
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                MaterialIcon {
                    text: root.selected ? WidgetRegistry.get(root.selected.wType).icon : "tune"
                    color: Colours.palette.m3primary
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.selected ? WidgetRegistry.get(root.selected.wType).name : qsTr("Details & layers")
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
            }
            StyledText {
                Layout.fillWidth: true
                visible: !root.selected
                text: root.widgets.length ? qsTr("Select a widget on the canvas or from the layers below.") : qsTr("Add a widget to customize its size, style and appearance.")
                wrapMode: Text.WordWrap
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: !root.selected
                spacing: 4
                Repeater {
                    model: root.widgets.slice().reverse()
                    TextButton {
                        required property var modelData
                        Layout.fillWidth: true
                        text: `${WidgetRegistry.get(modelData.wType).name} · ${modelData.wVariant}`
                        type: TextButton.Tonal
                        onClicked: root.selectionRequested(String(modelData.wId), false)
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: !!root.selected
                spacing: 12
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: root.selected ? WidgetRegistry.get(root.selected.wType).variants : []
                        TextButton {
                            required property string modelData
                            text: modelData
                            font.pointSize: Tokens.font.size.small
                            type: modelData === root.selected?.wVariant ? TextButton.Filled : TextButton.Tonal
                            onClicked: if (root.selected)
                                root.variantRequested(String(root.selected.wId), modelData)
                        }
                    }
                }
                Divider {}
                Caption {
                    text: qsTr("Position & size")
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8
                    NumberEdit {
                        label: "X"
                        field: "x"
                        current: root.position.x
                        maximum: root.screen?.width ?? 1
                    }
                    NumberEdit {
                        label: "Y"
                        field: "y"
                        current: root.position.y
                        maximum: root.screen?.height ?? 1
                    }
                    NumberEdit {
                        label: qsTr("Width")
                        field: "width"
                        current: root.size.width
                        minimum: 1
                        maximum: root.screen?.width ?? 1
                    }
                    NumberEdit {
                        label: qsTr("Height")
                        field: "height"
                        current: root.size.height
                        minimum: 1
                        maximum: root.screen?.height ?? 1
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    TextButton {
                        Layout.fillWidth: true
                        text: root.aspectLock ? qsTr("Ratio locked") : qsTr("Lock ratio")
                        type: root.aspectLock ? TextButton.Filled : TextButton.Tonal
                        onClicked: root.aspectLockRequested(!root.aspectLock)
                    }
                    TextButton {
                        text: qsTr("Reset size")
                        type: TextButton.Text
                        onClicked: if (root.selected)
                            root.resetSizeRequested(String(root.selected.wId))
                    }
                }
                Caption {
                    text: qsTr("Anchor")
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    rowSpacing: 4
                    columnSpacing: 4
                    Repeater {
                        model: [
                            {
                                h: "left",
                                v: "top",
                                label: "↖"
                            },
                            {
                                h: "center",
                                v: "top",
                                label: "↑"
                            },
                            {
                                h: "right",
                                v: "top",
                                label: "↗"
                            },
                            {
                                h: "left",
                                v: "center",
                                label: "←"
                            },
                            {
                                h: "center",
                                v: "center",
                                label: "•"
                            },
                            {
                                h: "right",
                                v: "center",
                                label: "→"
                            },
                            {
                                h: "left",
                                v: "bottom",
                                label: "↙"
                            },
                            {
                                h: "center",
                                v: "bottom",
                                label: "↓"
                            },
                            {
                                h: "right",
                                v: "bottom",
                                label: "↘"
                            }
                        ]
                        TextButton {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.label
                            Accessible.name: qsTr("Anchor %1 %2").arg(modelData.v).arg(modelData.h)
                            type: root.selected?.anchorH === modelData.h && root.selected?.anchorV === modelData.v ? TextButton.Filled : TextButton.Tonal
                            onClicked: if (root.selected)
                                root.anchorRequested(String(root.selected.wId), modelData.h, modelData.v)
                        }
                    }
                }
                Divider {}
                Range {
                    label: qsTr("Opacity")
                    current: Number(root.selected?.wOpacity ?? 1)
                    low: 0.15
                    high: 1
                    field: "wOpacity"
                    percent: true
                }
                RowLayout {
                    Layout.fillWidth: true
                    Caption {
                        Layout.fillWidth: true
                        text: qsTr("Rotation")
                    }
                    TextButton {
                        text: "−90°"
                        type: TextButton.Tonal
                        onClicked: root.edit("wRotation", ((root.selected?.wRotation ?? 0) + 270) % 360)
                    }
                    TextButton {
                        text: `${root.selected?.wRotation ?? 0}°`
                        type: TextButton.Text
                        onClicked: root.edit("wRotation", 0)
                    }
                    TextButton {
                        text: "+90°"
                        type: TextButton.Tonal
                        onClicked: root.edit("wRotation", ((root.selected?.wRotation ?? 0) + 90) % 360)
                    }
                }
                TextButton {
                    Layout.fillWidth: true
                    text: root.selected?.wProps?.bgVisible === false ? qsTr("Show background") : qsTr("Hide background")
                    type: TextButton.Tonal
                    onClicked: root.edit("bgVisible", root.selected?.wProps?.bgVisible === false)
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.selected?.wProps?.bgVisible !== false
                    spacing: 10
                    Caption {
                        text: qsTr("Background")
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: ["surface", "primary", "secondary", "tertiary"]
                            TextButton {
                                required property string modelData
                                text: modelData
                                font.pointSize: Tokens.font.size.small
                                type: (root.selected?.wProps?.bgColor ?? "surface") === modelData ? TextButton.Filled : TextButton.Tonal
                                onClicked: root.edit("bgColor", modelData)
                            }
                        }
                    }
                    ColorEdit {
                        label: qsTr("Custom color")
                        field: "bgColor"
                        current: root.selected?.wProps?.bgColor ?? "surface"
                    }
                    TextButton {
                        Layout.fillWidth: true
                        text: root.selected?.wProps?.bgGradient ? qsTr("Gradient on") : qsTr("Gradient off")
                        type: TextButton.Tonal
                        onClicked: root.edit("bgGradient", !root.selected?.wProps?.bgGradient)
                    }
                    ColorEdit {
                        visible: root.selected?.wProps?.bgGradient === true
                        label: qsTr("End color")
                        field: "bgColor2"
                        current: root.selected?.wProps?.bgColor2 ?? "primary"
                    }
                    Range {
                        label: qsTr("Background opacity")
                        current: Number(root.selected?.wProps?.bgOpacity ?? 0.82)
                        low: 0
                        high: 1
                        field: "bgOpacity"
                        percent: true
                    }
                    Range {
                        label: qsTr("Corner radius")
                        current: Number(root.selected?.wProps?.bgRadius ?? 16)
                        low: 0
                        high: Math.max(1, Math.min(root.size.width, root.size.height) / 2)
                        field: "bgRadius"
                    }
                    Range {
                        label: qsTr("Border width")
                        current: Number(root.selected?.wProps?.bgBorderWidth ?? 0)
                        low: 0
                        high: 8
                        field: "bgBorderWidth"
                    }
                    ColorEdit {
                        label: qsTr("Border color")
                        field: "bgBorderColor"
                        current: root.selected?.wProps?.bgBorderColor ?? "surface"
                    }
                }
                Divider {}
                DraftEdit {
                    visible: ["user", "github"].includes(root.selected?.wType)
                    label: root.selected?.wType === "github" ? qsTr("GitHub username") : qsTr("Display name")
                    field: root.selected?.wType === "github" ? "username" : "displayName"
                    current: root.selected?.wProps?.[field] ?? ""
                }
                DraftEdit {
                    visible: root.selected?.wType === "note"
                    label: qsTr("Note")
                    field: "noteText"
                    current: root.selected?.wProps?.noteText ?? ""
                }
                ColumnLayout {
                    visible: root.selected?.wType === "music"
                    Layout.fillWidth: true
                    Caption {
                        text: qsTr("Music")
                    }
                    Repeater {
                        model: ["showAlbumArt", "showControls", "showProgress", "showVisualizer"]
                        TextButton {
                            required property string modelData
                            Layout.fillWidth: true
                            readonly property bool on: root.selected?.wProps?.[modelData] !== false
                            text: `${on ? "✓" : "○"} ${({
                                    showAlbumArt: qsTr("Album art"),
                                    showControls: qsTr("Playback controls"),
                                    showProgress: qsTr("Progress"),
                                    showVisualizer: qsTr("Visualizer")
                                })[modelData]}`
                            type: TextButton.Tonal
                            onClicked: root.edit(modelData, !on)
                        }
                    }
                    Range {
                        label: qsTr("Lyrics lines")
                        current: Number(root.selected?.wProps?.lyricsLines ?? 1)
                        low: 1
                        high: 6
                        field: "lyricsLines"
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.selected?.wType === "image"
                    Image {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        source: root.selected?.wImagePath ?? ""
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    DraftEdit {
                        label: qsTr("Image path")
                        field: "wImagePath"
                        current: root.selected?.wImagePath ?? ""
                    }
                    TextButton {
                        Layout.fillWidth: true
                        text: qsTr("Choose image")
                        onClicked: if (root.selected)
                            root.imageBrowseRequested(String(root.selected.wId))
                    }
                }
                TextButton {
                    visible: root.selected?.wType === "visualizer"
                    Layout.fillWidth: true
                    text: root.selected?.wProps?.stretchWidth ? qsTr("Use fixed width") : qsTr("Stretch width")
                    type: TextButton.Tonal
                    onClicked: root.edit("stretchWidth", !root.selected?.wProps?.stretchWidth)
                }
                RowLayout {
                    Layout.fillWidth: true
                    TextButton {
                        Layout.fillWidth: true
                        text: qsTr("Backward")
                        type: TextButton.Tonal
                        onClicked: if (root.selected)
                            root.orderRequested(String(root.selected.wId), -1)
                    }
                    TextButton {
                        Layout.fillWidth: true
                        text: qsTr("Forward")
                        type: TextButton.Tonal
                        onClicked: if (root.selected)
                            root.orderRequested(String(root.selected.wId), 1)
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    TextButton {
                        Layout.fillWidth: true
                        text: root.selected?.enabled === false ? qsTr("Show widget") : qsTr("Hide widget")
                        type: TextButton.Tonal
                        onClicked: root.edit("enabled", root.selected?.enabled === false)
                    }
                    TextButton {
                        text: qsTr("Remove")
                        type: TextButton.Text
                        label.color: Colours.palette.m3error
                        onClicked: if (root.selected)
                            root.removeRequested(String(root.selected.wId))
                    }
                }
                TextButton {
                    Layout.fillWidth: true
                    text: qsTr("View all layers")
                    type: TextButton.Text
                    onClicked: root.selectionRequested(String(root.selected?.wId ?? ""), true)
                }
            }
        }
    }
    component Caption: StyledText {
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
    }
    component Divider: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Qt.alpha(Colours.palette.m3outlineVariant, 0.6)
    }
    component Input: TextField {
        color: Colours.palette.m3onSurface
        selectionColor: Colours.palette.m3primary
        selectedTextColor: Colours.palette.m3onPrimary
        placeholderTextColor: Colours.palette.m3onSurfaceVariant
        font.family: Tokens.font.family.sans
        font.pointSize: Tokens.font.size.small
        padding: 10
        background: Rectangle {
            radius: 8
            color: Colours.palette.m3surface
            border.width: 1
            border.color: parent.activeFocus ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
        }
    }
    component NumberEdit: ColumnLayout {
        id: numberEdit
        required property string label
        required property string field
        required property real current
        property int minimum: 0
        required property int maximum
        Layout.fillWidth: true
        spacing: 4
        Caption {
            text: numberEdit.label
        }
        Input {
            Layout.fillWidth: true
            text: String(Math.round(numberEdit.current))
            validator: IntValidator {
                bottom: numberEdit.minimum
                top: Math.max(numberEdit.minimum, numberEdit.maximum)
            }
            onEditingFinished: {
                if (acceptableInput && root.selected)
                    root.geometryEdited(String(root.selected.wId), numberEdit.field, Number(text));
                text = Qt.binding(() => String(Math.round(numberEdit.current)));
            }
        }
    }
    component Range: ColumnLayout {
        id: range
        required property string label
        required property string field
        required property real current
        required property real low
        required property real high
        property bool percent: false
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            Caption {
                Layout.fillWidth: true
                text: range.label
                elide: Text.ElideRight
            }
            StyledText {
                font.pointSize: Tokens.font.size.small
                text: range.percent ? `${Math.round(range.current * 100)}%` : String(Math.round(range.current))
            }
        }
        Slider {
            id: slider
            Layout.fillWidth: true
            implicitHeight: 28
            from: range.low
            to: Math.max(range.low + 0.001, range.high)
            stepSize: range.percent ? 0.01 : 1
            value: Math.max(from, Math.min(to, range.current))
            onMoved: root.edit(range.field, range.percent ? value : Math.round(value))
            background: Rectangle {
                x: slider.leftPadding
                y: (slider.height - height) / 2
                width: Math.max(0, slider.availableWidth)
                height: 4
                radius: 2
                color: Colours.palette.m3surfaceContainerHighest
                Rectangle {
                    width: parent.width * slider.visualPosition
                    height: parent.height
                    radius: 2
                    color: Colours.palette.m3primary
                }
            }
            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * Math.max(0, slider.availableWidth - width)
                y: (slider.height - height) / 2
                width: 16
                height: 16
                radius: 8
                color: Colours.palette.m3primary
                border.width: slider.activeFocus ? 2 : 0
                border.color: Colours.palette.m3onPrimary
            }
        }
    }
    component DraftEdit: ColumnLayout {
        id: draft
        required property string label
        required property string field
        required property string current
        Layout.fillWidth: true
        spacing: 4
        Caption {
            text: draft.label
        }
        Input {
            Layout.fillWidth: true
            text: draft.current
            onEditingFinished: {
                root.edit(draft.field, text);
                text = Qt.binding(() => draft.current);
            }
        }
    }
    component ColorEdit: ColumnLayout {
        id: colorEdit
        required property string label
        required property string field
        required property string current
        Layout.fillWidth: true
        spacing: 4
        Caption {
            text: colorEdit.label
        }
        Input {
            Layout.fillWidth: true
            text: colorEdit.current
            placeholderText: "#RRGGBB"
            validator: RegularExpressionValidator {
                regularExpression: /#[0-9a-fA-F]{6}|surface|primary|secondary|tertiary/
            }
            onEditingFinished: {
                if (acceptableInput)
                    root.edit(colorEdit.field, text);
                text = Qt.binding(() => colorEdit.current);
            }
        }
    }
}

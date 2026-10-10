pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property DrawerVisibilities visibilities
    property string mode: "shot"
    property string target: ""
    property string monitorName: ""
    property string windowAddress: ""
    property bool includeSound: false
    property bool includeCursor: false

    readonly property var monitors: (CaptureSession.manifest.monitors ?? []).map(monitor => ({
        name: monitor.name,
        width: monitor.width,
        height: monitor.height,
        label: `${monitor.name} · ${monitor.width}×${monitor.height}`
    }))
    readonly property var windows: (CaptureSession.manifest.windows ?? []).map(window => ({
        address: window.address,
        label: `${window.title} — ${window.class}`
    }))
    readonly property int selectedMonitorIndex: Math.max(0, monitors.findIndex(monitor => monitor.name === monitorName))
    readonly property int selectedWindowIndex: Math.max(0, windows.findIndex(window => window.address === windowAddress))
    readonly property string actionText: mode === "shot" ? qsTr("Take screenshot") : qsTr("Start recording")
    readonly property string subtitle: target === "region"
        ? qsTr("Drag to choose the area after continuing")
        : target === "window" ? qsTr("Choose an open window")
        : target === "full" ? qsTr("Choose the display to capture")
        : qsTr("Choose a capture area")

    implicitWidth: Math.min(620, Quickshell.screens[0]?.width ?? 620)
    implicitHeight: panel.implicitHeight
    focus: true

    function close(): void {
        CaptureSession.cancel();
    }

    function start(): void {
        if (!target)
            return;
        CaptureSession.run({
            mode: mode,
            target: target,
            monitor: monitorName,
            windowAddress: windowAddress,
            sound: includeSound,
            cursor: includeCursor
        });
    }

    function chooseTarget(value: string): void {
        if (value === "window" && windows.length === 0)
            return;
        target = value;
    }

    function syncSession(): void {
        monitorName = CaptureSession.manifest.focusedMonitor ?? monitors[0]?.name ?? "";
        windowAddress = CaptureSession.manifest.focusedWindow ?? windows[0]?.address ?? "";
        target = "";
        mode = "shot";
        includeSound = false;
        includeCursor = false;
    }

    Component.onCompleted: {
        syncSession();
        forceActiveFocus();
    }

    Connections {
        target: CaptureSession
        function onManifestChanged(): void {
            root.syncSession();
        }
    }

    Keys.onEscapePressed: close()
    Keys.onReturnPressed: start()

    StyledRect {
        id: panel

        anchors.fill: parent
        implicitHeight: body.implicitHeight + body.anchors.margins * 2
        radius: Tokens.rounding.large
        color: Colours.palette.m3surface
        border.width: 1
        border.color: Colours.palette.m3surface

        ColumnLayout {
            id: body

            anchors.fill: parent
            anchors.margins: Tokens.padding.larger
            spacing: Tokens.spacing.normal

            RowLayout {
                spacing: Tokens.spacing.normal

                StyledRect {
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: Tokens.rounding.large
                    color: Colours.palette.m3primaryContainer

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "screenshot_monitor"
                        color: Colours.palette.m3onPrimaryContainer
                        font.pointSize: Tokens.font.size.large
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Capture studio")
                        font.pointSize: Tokens.font.size.large
                        font.weight: Font.DemiBold
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: subtitle
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.small
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    icon: "close"
                    type: IconButton.Text
                    onClicked: root.close()
                }
            }

            RowLayout {
                spacing: Tokens.spacing.small

                Repeater {
                    model: [
                        { value: "shot", label: qsTr("Screenshot"), icon: "photo_camera" },
                        { value: "record", label: qsTr("Record"), icon: "screen_record" }
                    ]

                    delegate: StyledRect {
                        id: modeCard

                        required property var modelData
                        readonly property bool active: root.mode === modelData.value

                        Layout.fillWidth: true
                        implicitHeight: 48
                        radius: Tokens.rounding.normal
                        color: active ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh

                        StateLayer {
                            color: modeCard.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            onClicked: root.mode = modeCard.modelData.value
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: modeCard.modelData.icon
                                color: modeCard.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            }

                            StyledText {
                                text: modeCard.modelData.label
                                color: modeCard.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                font.weight: modeCard.active ? Font.DemiBold : Font.Normal
                            }
                        }
                    }
                }
            }

            RowLayout {
                spacing: Tokens.spacing.small

                Repeater {
                    model: [
                        { value: "full", label: qsTr("Entire display"), icon: "monitor" },
                        { value: "window", label: qsTr("Window"), icon: "web_asset" },
                        { value: "region", label: qsTr("Area"), icon: "crop_free" }
                    ]

                    delegate: StyledRect {
                        id: targetCard

                        required property var modelData
                        readonly property bool active: root.target === modelData.value
                        readonly property bool unavailable: modelData.value === "window" && root.windows.length === 0

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 82
                        radius: Tokens.rounding.normal
                        color: active ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
                        opacity: unavailable ? 0.45 : 1

                        StateLayer {
                            color: targetCard.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                            disabled: targetCard.unavailable
                            onClicked: root.chooseTarget(targetCard.modelData.value)
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                Layout.alignment: Qt.AlignHCenter
                                text: targetCard.modelData.icon
                                color: targetCard.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                                font.pointSize: Tokens.font.size.large
                            }

                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: targetCard.modelData.label
                                color: targetCard.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                                font.pointSize: Tokens.font.size.small
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                visible: root.target === "full" && root.monitors.length > 0

                StyledText {
                    text: qsTr("Display")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                }

                ComboBox {
                    id: monitorSelector

                    Layout.fillWidth: true
                    model: root.monitors
                    textRole: "label"
                    currentIndex: root.selectedMonitorIndex
                    onActivated: index => root.monitorName = root.monitors[index]?.name ?? ""
                    contentItem: StyledText {
                        leftPadding: Tokens.padding.normal
                        rightPadding: Tokens.padding.large
                        text: monitorSelector.displayText
                        color: Colours.palette.m3onSurface
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    indicator: MaterialIcon {
                        x: monitorSelector.width - width - Tokens.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        text: "expand_more"
                        color: Colours.palette.m3onSurfaceVariant
                    }
                    background: StyledRect {
                        implicitHeight: 44
                        radius: Tokens.rounding.normal
                        color: Colours.palette.m3surfaceContainerHigh
                    }

                    delegate: ItemDelegate {
                        id: monitorOption

                        required property int index
                        required property var modelData
                        width: monitorSelector.width
                        highlighted: monitorSelector.highlightedIndex === index
                        background: StyledRect {
                            radius: Tokens.rounding.small
                            color: monitorOption.highlighted ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh
                        }
                        contentItem: StyledText {
                            text: modelData.label
                            leftPadding: Tokens.padding.normal
                            color: monitorOption.highlighted ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                    popup.padding: Tokens.padding.small
                    popup.background: StyledRect {
                        radius: Tokens.rounding.normal
                        color: Colours.palette.m3surfaceContainerHigh
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                visible: root.target === "window" && root.windows.length > 0

                StyledText {
                    text: qsTr("Window")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                }

                ComboBox {
                    id: windowSelector

                    Layout.fillWidth: true
                    model: root.windows
                    textRole: "label"
                    currentIndex: root.selectedWindowIndex
                    onActivated: index => root.windowAddress = root.windows[index]?.address ?? ""
                    contentItem: StyledText {
                        leftPadding: Tokens.padding.normal
                        rightPadding: Tokens.padding.large
                        text: windowSelector.displayText
                        color: Colours.palette.m3onSurface
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    indicator: MaterialIcon {
                        x: windowSelector.width - width - Tokens.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        text: "expand_more"
                        color: Colours.palette.m3onSurfaceVariant
                    }
                    background: StyledRect {
                        implicitHeight: 44
                        radius: Tokens.rounding.normal
                        color: Colours.palette.m3surfaceContainerHigh
                    }

                    delegate: ItemDelegate {
                        id: windowOption

                        required property int index
                        required property var modelData
                        width: windowSelector.width
                        highlighted: windowSelector.highlightedIndex === index
                        background: StyledRect {
                            radius: Tokens.rounding.small
                            color: windowOption.highlighted ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh
                        }
                        contentItem: StyledText {
                            text: modelData.label
                            leftPadding: Tokens.padding.normal
                            color: windowOption.highlighted ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                    popup.padding: Tokens.padding.small
                    popup.background: StyledRect {
                        radius: Tokens.rounding.normal
                        color: Colours.palette.m3surfaceContainerHigh
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.normal
                visible: root.target !== ""

                SwitchRow {
                    Layout.fillWidth: true
                    label: root.mode === "shot" ? qsTr("Include pointer") : qsTr("Record system audio")
                    checked: root.mode === "shot" ? root.includeCursor : root.includeSound
                    onToggled: checked => {
                        if (root.mode === "shot")
                            root.includeCursor = checked;
                        else
                            root.includeSound = checked;
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Tokens.rounding.normal
                color: !root.target ? Colours.palette.m3surfaceContainerHigh : Colours.palette.m3primary
                opacity: root.target ? 1 : 0.55

                StateLayer {
                    disabled: !root.target
                    color: Colours.palette.m3onPrimary
                    onClicked: root.start()
                }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: root.mode === "shot" ? "photo_camera" : "radio_button_checked"
                        color: Colours.palette.m3onPrimary
                    }

                    StyledText {
                        text: root.target === "region" && root.mode === "shot" ? qsTr("Choose area") : root.actionText
                        color: Colours.palette.m3onPrimary
                        font.weight: Font.DemiBold
                    }
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Enter to continue · Esc to close")
                color: Colours.palette.m3outline
                font.pointSize: Tokens.font.size.smaller
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property var widget

    readonly property real inset: Math.max(8, Math.min(14, width * 0.035))
    readonly property real gap: Math.max(6, Math.min(10, width * 0.025))
    readonly property real avatarSize: Math.min(height - inset * 2 - 42, width * 0.28, 88)
    readonly property string avatarPath: avatarOverride || `${Paths.home}/.face`
    property string avatarOverride: ""

    function chooseAvatar(): void {
        avatarPicker.open();
    }

    FileDialog {
        id: avatarPicker
        title: qsTr("Choose a profile picture")
        filterLabel: qsTr("Image files")
        filters: Images.validImageExtensions
        onAccepted: path => {
            if (CUtils.copyFile(Qt.resolvedUrl(path), Qt.resolvedUrl(`${Paths.home}/.face`))) {
                root.avatarOverride = `${Paths.home}/.face`;
                avatar.source = "";
                Qt.callLater(() => avatar.source = `file://${root.avatarPath}`);
            } else {
                Quickshell.execDetached(["notify-send", "Could not update profile picture"]);
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.inset
        spacing: root.gap

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.gap

            Item {
                id: avatarCard
                Layout.preferredWidth: Math.max(48, root.avatarSize)
                Layout.preferredHeight: Math.max(48, root.avatarSize)

                StyledClippingRect {
                    id: avatarShape
                    anchors.fill: parent
                    radius: Tokens.rounding.large
                    color: Colours.palette.m3surfaceContainerHighest

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "person_add"
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Math.min(34, avatarCard.width * 0.43)
                        visible: avatar.status !== Image.Ready
                    }

                    Image {
                        id: avatar
                        anchors.fill: parent
                        source: `file://${root.avatarPath}`
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        smooth: true
                        sourceSize: Qt.size(width * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1), height * ((QsWindow.window as QsWindow)?.devicePixelRatio ?? 1))
                        visible: status === Image.Ready
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.alpha(Colours.palette.m3scrim, 0.48)
                        opacity: avatarHover.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160 } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "edit"
                            color: Colours.palette.m3onSurface
                            font.pointSize: 24
                        }
                    }
                }

                MouseArea {
                    id: avatarHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chooseAvatar()
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.gap

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.rounding.small
                    color: Colours.palette.m3secondaryContainer

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.gap
                        anchors.rightMargin: root.gap
                        spacing: root.gap

                        MaterialIcon {
                            text: "person"
                            color: Colours.palette.m3onSecondaryContainer
                            font.pointSize: 18
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            StyledText {
                                Layout.fillWidth: true
                                text: root.widget.wProps?.displayName || Quickshell.env("USER") || qsTr("User")
                                color: Colours.palette.m3onSecondaryContainer
                                font.pointSize: Tokens.font.size.normal
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Quickshell.env("USER") || ""
                                color: Colours.palette.m3onSecondaryContainer
                                opacity: 0.78
                                font.pointSize: Tokens.font.size.small
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.rounding.small
                    color: Colours.palette.m3surfaceContainerHigh

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: root.gap
                        anchors.rightMargin: root.gap
                        spacing: root.gap
                        MaterialIcon {
                            text: "select_window"
                            color: Colours.palette.m3primary
                            font.pointSize: 18
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("%1 session").arg(Quickshell.env("XDG_SESSION_DESKTOP") || "Hyprland")
                            color: Colours.palette.m3onSurface
                            font.pointSize: Tokens.font.size.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(34, Math.min(44, parent.height * 0.27))
            spacing: root.gap * 0.7

            Repeater {
                model: [
                    { command: "lock", icon: "lock", fill: Colours.palette.m3secondaryContainer, onFill: Colours.palette.m3onSecondaryContainer, weight: 0.8 },
                    { command: "suspend", icon: "bedtime", fill: Colours.palette.m3secondaryContainer, onFill: Colours.palette.m3onSecondaryContainer, weight: 1.0 },
                    { command: "reboot", icon: "restart_alt", fill: Colours.palette.m3tertiaryContainer, onFill: Colours.palette.m3onTertiaryContainer, weight: 2.0 },
                    { command: "poweroff", icon: "power_settings_new", fill: Colours.palette.m3errorContainer, onFill: Colours.palette.m3onErrorContainer, weight: 3.0 }
                ]

                delegate: Rectangle {
                    id: action
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.rounding.small
                    clip: true
                    color: mouse.containsMouse ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3surfaceContainer
                    property real fillLevel: 0
                    property real phase: 0
                    property bool triggered: false
                    property real weight: modelData.weight
                    property int chargingSoundHandle: Sounds.invalidHandle

                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    scale: mouse.pressed ? 0.96 : mouse.containsMouse ? 1.025 : 1

                    Canvas {
                        id: wave
                        anchors.fill: parent
                        visible: action.fillLevel > 0.001
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()
                        Connections {
                            target: action
                            function onFillLevelChanged() { wave.requestPaint(); }
                            function onPhaseChanged() { wave.requestPaint(); }
                        }
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            const level = Math.max(0, Math.min(1, action.fillLevel));
                            const surfaceY = height * (1 - level);
                            const amp = level < 0.98 ? Math.min(6, height * 0.18) * Math.sin(level * Math.PI) : 0;
                            ctx.beginPath();
                            ctx.moveTo(0, height);
                            ctx.lineTo(0, surfaceY + Math.sin(action.phase) * amp);
                            for (let x = 0; x <= width; x += 4) {
                                const y = surfaceY + Math.sin(action.phase + x / Math.max(1, width) * Math.PI * 2) * amp;
                                ctx.lineTo(x, y);
                            }
                            ctx.lineTo(width, height);
                            ctx.closePath();
                            ctx.fillStyle = action.modelData.fill;
                            ctx.fill();
                        }
                    }

                    NumberAnimation on phase {
                        from: 0
                        to: Math.PI * 2
                        duration: 850
                        loops: Animation.Infinite
                        running: action.fillLevel > 0 && action.fillLevel < 1
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: action.modelData.icon
                        color: mouse.containsMouse ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                        font.pointSize: Math.min(22, parent.height * 0.48)
                    }

                    // Re-draw the action glyph over the filled area for contrast.
                    Item {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: parent.height * action.fillLevel
                        clip: true
                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: action.height / 2 - height / 2 - (action.height - parent.height)
                            text: action.modelData.icon
                            color: action.modelData.onFill
                            font.pointSize: Math.min(22, action.height * 0.48)
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: action.triggered ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onPressed: {
                            if (!action.triggered && action.modelData.command !== "lock") {
                                if (action.chargingSoundHandle !== Sounds.invalidHandle)
                                    Sounds.stopSfx(action.chargingSoundHandle);
                                action.chargingSoundHandle = Sounds.playUntilStopped("reusables/fillbutton/charge_loop.wav", 0.6, false);
                                drain.stop();
                                fill.start();
                            }
                        }
                        onReleased: {
                            if (action.chargingSoundHandle !== Sounds.invalidHandle) {
                                Sounds.stopSfx(action.chargingSoundHandle);
                                action.chargingSoundHandle = Sounds.invalidHandle;
                            }
                            if (!action.triggered && action.fillLevel < 1) { fill.stop(); drain.start(); }
                        }
                        onCanceled: {
                            if (action.chargingSoundHandle !== Sounds.invalidHandle) {
                                Sounds.stopSfx(action.chargingSoundHandle);
                                action.chargingSoundHandle = Sounds.invalidHandle;
                            }
                            if (!action.triggered) { fill.stop(); drain.start(); }
                        }
                        onClicked: if (action.modelData.command === "lock") {
                            Sounds.playSfx("reusables/fillbutton/button.wav");
                            Quickshell.execDetached(["loginctl", "lock-session"]);
                        }
                    }

                    NumberAnimation {
                        id: fill
                        target: action
                        property: "fillLevel"
                        to: 1
                        duration: 550 * action.weight * (1 - action.fillLevel)
                        easing.type: Easing.InSine
                        onFinished: {
                            action.triggered = true;
                            if (action.chargingSoundHandle !== Sounds.invalidHandle) {
                                Sounds.stopSfx(action.chargingSoundHandle);
                                action.chargingSoundHandle = Sounds.invalidHandle;
                            }
                            Sounds.playSfx("reusables/fillbutton/button.wav");
                            drain.start();
                            execute.start();
                        }
                    }
                    NumberAnimation {
                        id: drain
                        target: action
                        property: "fillLevel"
                        to: 0
                        duration: 900 * action.fillLevel
                        easing.type: Easing.OutQuad
                    }
                    Timer {
                        id: execute
                        interval: 450
                        onTriggered: {
                            if (action.modelData.command === "lock")
                                Quickshell.execDetached(["loginctl", "lock-session"]);
                            else
                                Quickshell.execDetached(["systemctl", action.modelData.command]);
                            action.triggered = false;
                        }
                    }

                    Component.onDestruction: {
                        if (action.chargingSoundHandle !== Sounds.invalidHandle)
                            Sounds.stopSfx(action.chargingSoundHandle);
                    }
                }
            }
        }
    }
}

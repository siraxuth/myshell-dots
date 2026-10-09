pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property Session session

    PaneFrame {
        anchors.fill: parent

        Flickable {
            anchors.fill: parent
            contentHeight: layout.implicitHeight
            clip: true

            ColumnLayout {
                id: layout

                width: parent.width
                spacing: Tokens.spacing.normal

            SettingsHeader {
                icon: "bolt"
                title: qsTr("Power & Sleep")
            }

            // ── Power profile ─────────────────────────────────────────────
            SectionHeader {
                Layout.topMargin: Tokens.spacing.large
                title: qsTr("Power profile")
                description: qsTr("power-profiles-daemon")
            }

            SectionContainer {
                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Pill {
                        label: qsTr("Power saver")
                        on: PowerPrefs.profile === "power-saver"
                        onChose: PowerPrefs.setProfile("power-saver")
                    }
                    Pill {
                        label: qsTr("Balanced")
                        on: PowerPrefs.profile === "balanced"
                        onChose: PowerPrefs.setProfile("balanced")
                    }
                    Pill {
                        label: qsTr("Performance")
                        on: PowerPrefs.profile === "performance"
                        onChose: PowerPrefs.setProfile("performance")
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: UPower.onBattery ? qsTr("Power saver is active on battery. Your selected profile is restored when AC power returns.") : qsTr("This profile is used while connected to AC power. Power saver is selected automatically on battery.")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
            }

            SectionHeader {
                visible: PowerPrefs.gpuAvailable
                Layout.topMargin: Tokens.spacing.large
                title: qsTr("Discrete GPU")
                description: qsTr("NVIDIA runtime power management · %1").arg(PowerPrefs.gpuRuntimeStatus || qsTr("checking"))
            }

            SectionContainer {
                visible: PowerPrefs.gpuAvailable
                contentSpacing: Tokens.spacing.normal

                Flow {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    Pill {
                        label: qsTr("Automatic")
                        on: PowerPrefs.gpuMode === "automatic"
                        onChose: PowerPrefs.setGpuMode("automatic")
                    }
                    Pill {
                        label: qsTr("Power save")
                        on: PowerPrefs.gpuMode === "power-save"
                        onChose: PowerPrefs.setGpuMode("power-save")
                    }
                    Pill {
                        label: qsTr("Keep on")
                        on: PowerPrefs.gpuMode === "on"
                        onChose: PowerPrefs.setGpuMode("on")
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: PowerPrefs.gpuError || (PowerPrefs.gpuMode === "automatic" ? qsTr("Automatic enables runtime power saving on battery and restores the GPU on AC. Apps can wake the GPU when needed.") : PowerPrefs.gpuMode === "power-save" ? qsTr("Runtime power saving stays enabled; apps can wake the GPU when needed.") : qsTr("Keeps the NVIDIA GPU available and can use more battery."))
                    color: PowerPrefs.gpuError ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                }
            }

            SectionHeader {
                Layout.topMargin: Tokens.spacing.large
                title: qsTr("Battery brightness")
                description: qsTr("Lower the display brightness automatically on battery")
            }

            SectionContainer {
                contentSpacing: Tokens.spacing.normal

                SliderInput {
                    Layout.fillWidth: true
                    label: qsTr("Battery brightness target")
                    value: PowerPrefs.batteryBrightnessTarget
                    from: 20
                    to: 60
                    stepSize: 1
                    suffix: "%"
                    decimals: 0
                    onValueModified: value => PowerPrefs.setBatteryBrightnessTarget(Math.round(value))
                }

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: qsTr("Brightness is reduced to this level on battery and restored when AC power returns. You can still adjust it manually while unplugged.")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                }
            }

            // ── On charger ────────────────────────────────────────────────
            SectionHeader {
                Layout.topMargin: Tokens.spacing.large
                title: qsTr("On charger (AC)")
                description: qsTr("Idle behaviour while plugged in")
            }

            SectionContainer {
                contentSpacing: Tokens.spacing.normal

                TimeoutRow {
                    title: qsTr("Turn off screen")
                    seconds: PowerPrefs.acScreenOff
                    onChose: s => PowerPrefs.setTimeout("acScreenOff", s)
                }
                TimeoutRow {
                    title: qsTr("Lock")
                    seconds: PowerPrefs.acLock
                    onChose: s => PowerPrefs.setTimeout("acLock", s)
                }
                TimeoutRow {
                    title: qsTr("Suspend")
                    seconds: PowerPrefs.acSuspend
                    onChose: s => PowerPrefs.setTimeout("acSuspend", s)
                }
                LidActionRow {
                    action: PowerPrefs.acLidAction
                    onChose: action => PowerPrefs.setLidAction("acLidAction", action)
                }
            }

            // ── On battery ────────────────────────────────────────────────
            SectionHeader {
                Layout.topMargin: Tokens.spacing.large
                title: qsTr("On battery")
                description: qsTr("Idle behaviour while unplugged")
            }

            SectionContainer {
                contentSpacing: Tokens.spacing.normal

                TimeoutRow {
                    title: qsTr("Turn off screen")
                    seconds: PowerPrefs.batScreenOff
                    onChose: s => PowerPrefs.setTimeout("batScreenOff", s)
                }
                TimeoutRow {
                    title: qsTr("Lock")
                    seconds: PowerPrefs.batLock
                    onChose: s => PowerPrefs.setTimeout("batLock", s)
                }
                TimeoutRow {
                    title: qsTr("Suspend")
                    seconds: PowerPrefs.batSuspend
                    onChose: s => PowerPrefs.setTimeout("batSuspend", s)
                }
                LidActionRow {
                    action: PowerPrefs.batLidAction
                    onChose: action => PowerPrefs.setLidAction("batLidAction", action)
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                wrapMode: Text.Wrap
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                text: qsTr("Settings switch automatically between AC and battery. \"Never\" disables an idle action. Idle suspend uses suspend-then-hibernate. With an external display, closing the lid only turns off the laptop screen.")
            }
            }
        }
    }

    component Pill: StyledRect {
        id: pill

        property string label
        property bool on: false
        signal chose

        implicitWidth: pt.implicitWidth + Tokens.padding.large * 2
        implicitHeight: pt.implicitHeight + Tokens.padding.normal * 2
        radius: Tokens.rounding.full
        color: on ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainer, 2)

        StateLayer {
            radius: parent.radius
            color: pill.on ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: pill.chose()
        }

        StyledText {
            id: pt

            anchors.centerIn: parent
            text: pill.label
            color: pill.on ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.small
        }
    }

    component TimeoutRow: ColumnLayout {
        id: tr

        property string title
        property int seconds: 0
        signal chose(int s)

        readonly property var opts: [0, 60, 120, 300, 600, 900, 1800]
        readonly property var labels: [qsTr("Never"), "1m", "2m", "5m", "10m", "15m", "30m"]

        Layout.fillWidth: true
        spacing: Tokens.spacing.small / 2

        StyledText {
            text: tr.title
            color: Colours.palette.m3onSurface
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: tr.opts.length

                Pill {
                    required property int index

                    label: tr.labels[index]
                    on: tr.seconds === tr.opts[index]
                    onChose: tr.chose(tr.opts[index])
                }
            }
        }
    }

    component LidActionRow: ColumnLayout {
        id: lidRow

        property string action: "suspend"
        signal chose(string action)

        Layout.fillWidth: true
        spacing: Tokens.spacing.small / 2

        StyledText {
            text: qsTr("When I close the lid")
            color: Colours.palette.m3onSurface
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Pill {
                label: qsTr("Sleep")
                on: lidRow.action === "suspend"
                onChose: lidRow.chose("suspend")
            }
            Pill {
                label: qsTr("Hibernate")
                on: lidRow.action === "hibernate"
                onChose: lidRow.chose("hibernate")
            }
        }
    }
}

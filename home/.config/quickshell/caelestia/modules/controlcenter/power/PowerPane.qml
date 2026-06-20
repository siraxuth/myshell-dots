pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property Session session

    Flickable {
        anchors.fill: parent
        contentHeight: layout.implicitHeight + Tokens.padding.large * 2
        clip: true

        ColumnLayout {
            id: layout

            x: Tokens.padding.large
            y: Tokens.padding.large
            width: parent.width - Tokens.padding.large * 2
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
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.small
                wrapMode: Text.Wrap
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                text: qsTr("Timings switch automatically between AC and battery. \"Never\" disables that action. Suspend uses suspend-then-hibernate.")
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
}

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
                    icon: "terminal"
                    title: qsTr("Foot Terminal")
                }

                SectionHeader {
                    Layout.topMargin: Tokens.spacing.large
                    title: qsTr("Frosted glass")
                    description: qsTr("Blur and background opacity")
                }

                SectionContainer {
                    contentSpacing: Tokens.spacing.normal

                    SwitchRow {
                        label: qsTr("Background blur")
                        checked: FootPrefs.blurEnabled
                        onToggled: enabled => FootPrefs.setBlurEnabled(enabled)
                    }

                    SliderInput {
                        Layout.fillWidth: true
                        label: qsTr("Background opacity")
                        value: FootPrefs.opacity * 100
                        from: 55
                        to: 100
                        stepSize: 1
                        suffix: "%"
                        decimals: 0
                        onValueModified: value => FootPrefs.setOpacity(value / 100)
                    }
                }

                SectionHeader {
                    Layout.topMargin: Tokens.spacing.large
                    title: qsTr("Cursor")
                    description: qsTr("Blink timing while typing")
                }

                SectionContainer {
                    contentSpacing: Tokens.spacing.normal

                    SwitchRow {
                        label: qsTr("Blinking cursor")
                        checked: FootPrefs.cursorBlinkEnabled
                        onToggled: enabled => FootPrefs.setCursorBlinkEnabled(enabled)
                    }

                    SliderInput {
                        Layout.fillWidth: true
                        visible: FootPrefs.cursorBlinkEnabled
                        label: qsTr("Blink interval")
                        value: FootPrefs.cursorBlinkRate
                        from: 250
                        to: 1000
                        stepSize: 50
                        suffix: "ms"
                        decimals: 0
                        onValueModified: value => FootPrefs.setCursorBlinkRate(Math.round(value))
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: FootPrefs.loaded ? qsTr("Changes are saved to foot.ini. Restart Foot windows to apply them. Some terminal apps can override cursor blinking.") : qsTr("Loading Foot settings…")
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                }
            }
        }
    }
}

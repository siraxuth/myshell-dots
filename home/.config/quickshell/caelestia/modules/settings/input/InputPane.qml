pragma ComponentBehavior: Bound

import "../components"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.modules.settings
import qs.services

Item {
    id: root

    required property Session session

    PaneFrame {
        anchors.fill: parent

        Flickable {
            id: page
            anchors.fill: parent
            contentWidth: width
            contentHeight: settings.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick

            SettingsScrollHandler { flickable: page }

            ColumnLayout {
                id: settings
                width: page.width
                spacing: Tokens.spacing.normal

                SettingsHeader {
                    icon: "mouse"
                    title: qsTr("Mouse & pointer")
                }

                SectionHeader {
                    title: qsTr("Pointer speed")
                    description: qsTr("Adjust mouse sensitivity in Hyprland. Changes apply immediately and are saved for your next login.")
                }

                SectionContainer {
                    Layout.fillWidth: true

                    SliderInput {
                        Layout.fillWidth: true
                        label: qsTr("Mouse sensitivity")
                        from: -1
                        to: 1
                        stepSize: 0.05
                        decimals: 2
                        value: PointerPrefs.mouseSensitivity
                        formatValueFunction: value => `${value.toFixed(2)}${Math.abs(value) < 0.025 ? " · Default" : ""}`
                        onValueModified: value => PointerPrefs.setMouseSensitivity(value)
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                    text: qsTr("Hyprland sensitivity ranges from −1 (slower) through 0 (default) to +1 (faster). This controls pointer movement, not scroll speed.")
                }
            }
        }
    }
}

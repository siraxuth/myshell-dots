pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    Layout.fillWidth: true
    spacing: Tokens.spacing.normal

    property bool soundEnabled: Config.notifs.soundEnabled ?? true
    property string soundId: Config.notifs.soundId ?? "soft"
    property real soundVolume: Config.notifs.soundVolume ?? 0.45

    function save(): void {
        Config.notifs.soundEnabled = root.soundEnabled;
        Config.notifs.soundId = root.soundId;
        Config.notifs.soundVolume = root.soundVolume;
        Config.save();
    }

    SectionHeader {
        title: qsTr("Notification sound")
        description: qsTr("Choose and adjust the sound played for new notifications")
    }

    SectionContainer {
        Layout.fillWidth: true
        contentSpacing: Tokens.spacing.normal

        SwitchRow {
            label: qsTr("Play notification sound")
            checked: root.soundEnabled
            onToggled: checked => {
                root.soundEnabled = checked;
                root.save();
            }
        }

        SplitButtonRow {
            label: qsTr("Sound")
            enabled: root.soundEnabled
            active: root.soundId === "crisp" ? crispSoundItem : softSoundItem
            menuItems: [softSoundItem, crispSoundItem]

            MenuItem {
                id: softSoundItem
                text: qsTr("Soft chime")
                icon: "notifications"
                activeText: qsTr("Soft chime")
                onClicked: {
                    root.soundId = "soft";
                    root.save();
                }
            }

            MenuItem {
                id: crispSoundItem
                text: qsTr("Clear chime")
                icon: "graphic_eq"
                activeText: qsTr("Clear chime")
                onClicked: {
                    root.soundId = "crisp";
                    root.save();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            SliderInput {
                Layout.fillWidth: true
                label: qsTr("Sound volume")
                value: Math.round(root.soundVolume * 100)
                from: 0
                to: 100
                stepSize: 1
                suffix: "%"
                decimals: 0
                enabled: root.soundEnabled
                onValueModified: value => {
                    root.soundVolume = Math.max(0, Math.min(1, value / 100));
                    root.save();
                }
            }

            TextButton {
                Layout.alignment: Qt.AlignBottom
                text: qsTr("Preview")
                type: TextButton.Tonal
                enabled: root.soundEnabled
                onClicked: Sounds.previewNotification()
            }
        }
    }
}

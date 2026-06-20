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

    readonly property var widgets: Config.background.widgets
    readonly property var positions: ["top-left", "top-center", "top-right", "middle-left", "middle-center", "middle-right", "bottom-left", "bottom-center", "bottom-right"]

    function mutate(fn: var): void {
        const w = (GlobalConfig.background.widgets || []).map(x => Object.assign({}, x));
        fn(w);
        GlobalConfig.background.widgets = w;
    }
    function setField(i: int, k: string, v: var): void {
        mutate(w => {
            if (w[i])
                w[i][k] = v;
        });
    }
    function addWidget(): void {
        mutate(w => w.push({
            type: "media",
            enabled: true,
            position: "bottom-right",
            scale: 1.0
        }));
    }
    function delWidget(i: int): void {
        mutate(w => w.splice(i, 1));
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + Tokens.padding.large * 2
        clip: true

        ColumnLayout {
            id: col

            x: Tokens.padding.large
            y: Tokens.padding.large
            width: parent.width - Tokens.padding.large * 2
            spacing: Tokens.spacing.normal

            SettingsHeader {
                icon: "widgets"
                title: qsTr("Desktop Widgets")
            }

            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
                text: qsTr("Widgets shown on the wallpaper (visible on the empty desktop).")
            }

            Repeater {
                model: root.widgets

                WidgetCard {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    Layout.topMargin: Tokens.spacing.small
                    wType: modelData.type ?? "media"
                    wEnabled: modelData.enabled ?? true
                    wPosition: modelData.position ?? "bottom-left"
                    wScale: modelData.scale ?? 1.0
                    idx: index
                }
            }

            StyledRect {
                Layout.topMargin: Tokens.spacing.normal
                implicitWidth: addRow.implicitWidth + Tokens.padding.large * 2
                implicitHeight: addRow.implicitHeight + Tokens.padding.normal * 2
                radius: Tokens.rounding.full
                color: Colours.palette.m3primaryContainer

                StateLayer {
                    radius: parent.radius
                    color: Colours.palette.m3onPrimaryContainer
                    onClicked: root.addWidget()
                }

                RowLayout {
                    id: addRow

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "add"
                        color: Colours.palette.m3onPrimaryContainer
                    }
                    StyledText {
                        text: qsTr("Add widget")
                        color: Colours.palette.m3onPrimaryContainer
                    }
                }
            }
        }
    }

    component Pill: StyledRect {
        id: pill

        property string label
        property string icon: ""
        property bool on: false
        signal chose

        implicitWidth: pr.implicitWidth + Tokens.padding.normal * 2
        implicitHeight: pr.implicitHeight + Tokens.padding.small * 2
        radius: Tokens.rounding.full
        color: on ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainer, 2)

        StateLayer {
            radius: parent.radius
            color: pill.on ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
            onClicked: pill.chose()
        }

        RowLayout {
            id: pr

            anchors.centerIn: parent
            spacing: Tokens.spacing.small / 2

            MaterialIcon {
                visible: pill.icon !== ""
                text: pill.icon
                color: pill.on ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.small
            }
            StyledText {
                text: pill.label
                color: pill.on ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.small
            }
        }
    }

    component WidgetCard: StyledRect {
        id: card

        property string wType
        property bool wEnabled
        property string wPosition
        property real wScale
        property int idx

        implicitHeight: cardCol.implicitHeight + Tokens.padding.large * 2
        radius: Tokens.rounding.normal
        color: Colours.layer(Colours.palette.m3surfaceContainer, 1)

        ColumnLayout {
            id: cardCol

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                Pill {
                    label: qsTr("Media")
                    icon: "music_note"
                    on: card.wType === "media"
                    onChose: root.setField(card.idx, "type", "media")
                }
                Pill {
                    label: qsTr("Weather")
                    icon: "cloud"
                    on: card.wType === "weather"
                    onChose: root.setField(card.idx, "type", "weather")
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledRect {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: Tokens.rounding.full
                    color: card.wEnabled ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest

                    StateLayer {
                        radius: parent.radius
                        onClicked: root.setField(card.idx, "enabled", !card.wEnabled)
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: card.wEnabled ? "visibility" : "visibility_off"
                        color: card.wEnabled ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.small
                    }
                }

                StyledRect {
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: Tokens.rounding.full
                    color: "transparent"

                    StateLayer {
                        radius: parent.radius
                        color: Colours.palette.m3error
                        onClicked: root.delWidget(card.idx)
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "delete"
                        color: Colours.palette.m3error
                        font.pointSize: Tokens.font.size.small
                    }
                }
            }

            // 3x3 position grid
            Grid {
                columns: 3
                spacing: Tokens.spacing.small / 2

                Repeater {
                    model: 9

                    StyledRect {
                        required property int index

                        readonly property string pos: root.positions[index]
                        readonly property bool sel: card.wPosition === pos

                        implicitWidth: 30
                        implicitHeight: 20
                        radius: Tokens.rounding.small
                        color: sel ? Colours.palette.m3primary : Colours.layer(Colours.palette.m3surfaceContainer, 2)

                        StateLayer {
                            radius: parent.radius
                            onClicked: root.setField(card.idx, "position", parent.pos)
                        }
                    }
                }
            }

            RowLayout {
                Layout.topMargin: Tokens.spacing.small / 2
                spacing: Tokens.spacing.small

                StyledText {
                    text: qsTr("Scale")
                    color: Colours.palette.m3onSurfaceVariant
                    Layout.rightMargin: Tokens.spacing.small
                }

                Repeater {
                    model: [0.75, 1.0, 1.25, 1.5]

                    Pill {
                        required property var modelData

                        label: "×" + modelData
                        on: Math.abs(card.wScale - modelData) < 0.01
                        onChose: root.setField(card.idx, "scale", modelData)
                    }
                }
            }
        }
    }
}

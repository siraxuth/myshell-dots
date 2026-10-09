pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property alias layout: layout
    readonly property alias items: items
    readonly property alias expandIcon: expandIcon
    required property bool isHorizontal

    readonly property int padding: Config.bar.tray.background ? Tokens.padding.normal : Tokens.padding.small
    readonly property int spacing: Config.bar.tray.background ? Tokens.spacing.small : 0

    property bool expanded

    readonly property real nonAnimHeight: {
        if (!Config.bar.tray.compact)
            return layout.implicitHeight + padding * 2;
        return (expanded ? expandIcon.implicitHeight + layout.implicitHeight + spacing : expandIcon.implicitHeight) + padding * 2;
    }
    readonly property real nonAnimWidth: isHorizontal ? layout.implicitWidth + padding * 2 : Tokens.sizes.bar.innerWidth

    clip: true
    visible: height > 0

    implicitWidth: isHorizontal ? nonAnimWidth : Tokens.sizes.bar.innerWidth
    implicitHeight: isHorizontal ? Tokens.sizes.bar.innerWidth : nonAnimHeight

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, (Config.bar.tray.background && items.count > 0) ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    GridLayout {
        id: layout

        anchors.centerIn: parent
        columns: root.isHorizontal ? -1 : 1
        rows: root.isHorizontal ? 1 : -1
        columnSpacing: Tokens.spacing.small
        rowSpacing: Tokens.spacing.small

        opacity: root.expanded || !Config.bar.tray.compact ? 1 : 0

        Repeater {
            id: items

            model: ScriptModel {
                values: SystemTray.items.values.filter(i => !GlobalConfig.bar.tray.hiddenIcons.includes(i.id))
            }

            TrayItem {}
        }

        Behavior on opacity {
            Anim {}
        }
    }

    Loader {
        id: expandIcon

        asynchronous: true

        anchors.horizontalCenter: root.isHorizontal ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.isHorizontal ? parent.verticalCenter : undefined
        anchors.bottom: root.isHorizontal ? undefined : parent.bottom
        anchors.right: root.isHorizontal ? parent.right : undefined

        active: Config.bar.tray.compact && items.count > 0

        sourceComponent: Item {
            implicitWidth: expandIconInner.implicitWidth
            implicitHeight: expandIconInner.implicitHeight - Tokens.padding.small * 2

            MaterialIcon {
                id: expandIconInner

                anchors.horizontalCenter: root.isHorizontal ? undefined : parent.horizontalCenter
                anchors.verticalCenter: root.isHorizontal ? parent.verticalCenter : undefined
                anchors.bottom: root.isHorizontal ? undefined : parent.bottom
                anchors.right: root.isHorizontal ? parent.right : undefined
                anchors.bottomMargin: Config.bar.tray.background ? Tokens.padding.small : -Tokens.padding.small
                text: "expand_less"
                font.pointSize: Tokens.font.size.large
                rotation: root.expanded ? 180 : 0

                Behavior on rotation {
                    Anim {}
                }

                Behavior on anchors.bottomMargin {
                    Anim {}
                }
            }
        }
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }
}

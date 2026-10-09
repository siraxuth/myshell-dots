pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    required property var bar
    required property Brightness.Monitor monitor
    required property bool isHorizontal
    property color colour: Colours.palette.m3primary

    readonly property string windowTitle: {
        const title = Hypr.activeToplevel?.title;
        if (!title)
            return qsTr("Desktop");
        if (Config.bar.activeWindow.compact) {
            // " - " (standard hyphen), " — " (em dash), " – " (en dash)
            const parts = title.split(/\s+[\-\u2013\u2014]\s+/);
            if (parts.length > 1)
                return parts[parts.length - 1].trim();
        }
        return title;
    }

    readonly property int maxAlong: {
        const otherModules = bar.children.filter(c => c.id && c.item !== this && c.id !== "spacer");
        const otherHeight = otherModules.reduce((acc, curr) => acc + (isHorizontal ? (curr.item.nonAnimWidth ?? curr.width) : (curr.item.nonAnimHeight ?? curr.height)), 0);
        // Length - 2 cause repeater counts as a child
        return (isHorizontal ? bar.width : bar.height) - otherHeight - (isHorizontal ? bar.columnSpacing : bar.rowSpacing) * (bar.children.length - 1) - bar.vPadding * 2;
    }
    property Title current: text1

    clip: true
    implicitWidth: isHorizontal ? icon.implicitWidth + current.implicitWidth + Tokens.spacing.small : Math.max(icon.implicitWidth, current.implicitHeight)
    implicitHeight: isHorizontal ? Math.max(icon.implicitHeight, current.implicitHeight) : icon.implicitHeight + current.implicitWidth + current.anchors.topMargin

    Loader {
        asynchronous: true
        anchors.fill: parent
        active: !Config.bar.activeWindow.showOnHover

        sourceComponent: MouseArea {
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onPositionChanged: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent && popouts.currentName !== "activewindow")
                    popouts.hasCurrent = false;
            }
            onClicked: {
                const popouts = root.bar.popouts;
                if (popouts.hasCurrent) {
                    popouts.hasCurrent = false;
                } else {
                    popouts.currentName = "activewindow";
                    popouts.currentCenter = root.isHorizontal ? root.mapToItem(root.bar, root.implicitWidth / 2, 0).x : root.mapToItem(root.bar, 0, root.implicitHeight / 2).y;
                    popouts.hasCurrent = true;
                }
            }
        }
    }

    MaterialIcon {
        id: icon

        anchors.horizontalCenter: root.isHorizontal ? undefined : parent.horizontalCenter
        anchors.verticalCenter: root.isHorizontal ? parent.verticalCenter : undefined

        animate: true
        text: Icons.getAppCategoryIcon(Hypr.activeToplevel?.lastIpcObject.class, "desktop_windows")
        color: root.colour
    }

    Title {
        id: text1
    }

    Title {
        id: text2
    }

    TextMetrics {
        id: metrics

        text: root.windowTitle
        font.pointSize: root.Tokens.font.size.smaller
        font.family: root.Tokens.font.family.mono
        elide: Qt.ElideRight
        elideWidth: root.maxAlong - (root.isHorizontal ? icon.width : icon.height) - Tokens.spacing.small

        onTextChanged: {
            const next = root.current === text1 ? text2 : text1;
            next.text = elidedText;
            root.current = next;
        }
        onElideWidthChanged: root.current.text = elidedText
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    component Title: StyledText {
        id: text

        anchors.horizontalCenter: root.isHorizontal ? undefined : icon.horizontalCenter
        anchors.top: root.isHorizontal ? undefined : icon.bottom
        anchors.left: root.isHorizontal ? icon.right : undefined
        anchors.verticalCenter: root.isHorizontal ? icon.verticalCenter : undefined
        anchors.topMargin: root.isHorizontal ? 0 : Tokens.spacing.small
        anchors.leftMargin: root.isHorizontal ? Tokens.spacing.small : 0

        font.pointSize: metrics.font.pointSize
        font.family: metrics.font.family
        color: root.colour
        opacity: root.current === this ? 1 : 0

        transform: [
            Translate {
                x: !root.isHorizontal && root.Config.bar.activeWindow.inverted ? -text.implicitWidth + text.implicitHeight : 0
            },
            Rotation {
                angle: root.isHorizontal ? 0 : root.Config.bar.activeWindow.inverted ? 270 : 90
                origin.x: text.implicitHeight / 2
                origin.y: text.implicitHeight / 2
            }
        ]

        width: root.isHorizontal ? implicitWidth : implicitHeight
        height: root.isHorizontal ? implicitHeight : implicitWidth

        Behavior on opacity {
            Anim {}
        }
    }
}

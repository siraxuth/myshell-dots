pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property DrawerVisibilities visibilities
    required property FileDialog facePicker

    property color pfpFallbackColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

    implicitWidth: Tokens.sizes.dashboard.infoWidth + 220
    implicitHeight: 124

    Behavior on pfpFallbackColour {
        CAnim {}
    }

    MaterialShape {
        id: logoShape
        x: Tokens.padding.small
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: Tokens.font.size.extraLarge * 2.5
        shape: MaterialShape.Gem
        color: Colours.palette.m3primaryContainer

        Behavior on color { CAnim {} }

        Loader {
            anchors.centerIn: parent
            sourceComponent: SysInfo.isDefaultLogo ? caelestiaLogo : osLogo
        }
    }

    Component {
        id: osLogo

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: Tokens.font.size.extraLarge * 1.8
            colour: Colours.palette.m3onPrimaryContainer
        }
    }

    Component {
        id: caelestiaLogo

        Logo {
            implicitWidth: Tokens.font.size.extraLarge * 1.8
            implicitHeight: Tokens.font.size.extraLarge * 1.3
            topColour: Colours.palette.m3primary
            bottomColour: Colours.palette.m3onPrimaryContainer
        }
    }

    StyledClippingRect {
        id: pfpContainer

        anchors.left: logoShape.right
        anchors.leftMargin: -Tokens.padding.normal
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 116
        implicitHeight: 116
        radius: Math.min(width, height) / 2
        color: root.pfpFallbackColour

        Loader {
            anchors.centerIn: parent
            asynchronous: true
            active: pfp.status !== Image.Ready
            sourceComponent: MaterialIcon {
                text: "person_add"
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.extraLarge
                fill: 1
                grade: -2
            }
        }

        CachingImage {
            id: pfp
            anchors.fill: parent
            path: `${Paths.home}/.face`
        }

        StyledRect {
            anchors.fill: parent
            color: Qt.alpha(Colours.palette.m3scrim, pfp.status === Image.Ready ? 0.42 : 0)
            opacity: pfpMouse.containsMouse ? 1 : 0
            Behavior on opacity {
                Anim { type: Anim.DefaultEffects }
            }

            MaterialShape {
                anchors.centerIn: parent
                implicitSize: parent.height * 0.66
                shape: MaterialShape.Diamond
                color: Colours.palette.m3primary
                scale: pfpMouse.pressed ? 0.9 : pfpMouse.containsMouse ? 1 : 0.7

                Behavior on color { CAnim {} }
                Behavior on scale { Anim { type: Anim.FastSpatial } }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "person_edit"
                    color: Colours.palette.m3onPrimary
                    font.pointSize: Tokens.font.size.large
                }
            }
        }

        MouseArea {
            id: pfpMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.visibilities.dashboard = false;
                root.facePicker.open();
            }
        }
    }

    MaterialShape {
        id: uptimeShape
        anchors.left: pfpContainer.right
        anchors.leftMargin: -Tokens.padding.large
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Tokens.padding.small
        implicitSize: Tokens.font.size.large * 2.2
        shape: MaterialShape.Pill
        color: Colours.palette.m3tertiaryContainer

        Behavior on color { CAnim {} }

        MaterialIcon {
            anchors.centerIn: parent
            text: "clock_arrow_up"
            color: Colours.palette.m3onTertiaryContainer
            font.pointSize: Tokens.font.size.large
        }
    }

    StyledText {
        id: uptimeText
        anchors.left: uptimeShape.right
        anchors.leftMargin: Tokens.spacing.small
        anchors.verticalCenter: uptimeShape.verticalCenter
        width: Math.max(0, parent.width - x - Tokens.padding.large)
        text: qsTr("Up %1").arg(SysInfo.uptime)
        elide: Text.ElideRight
    }

    StyledRect {
        id: bubble1
        anchors.left: pfpContainer.right
        anchors.top: bubble2.bottom
        anchors.leftMargin: Tokens.spacing.small
        anchors.topMargin: -Tokens.spacing.extraSmall
        implicitWidth: 10
        implicitHeight: 10
        radius: Tokens.rounding.full
        color: Colours.palette.m3secondaryContainer
    }

    StyledRect {
        id: bubble2
        anchors.left: bubble1.right
        anchors.verticalCenter: wmContainer.bottom
        anchors.leftMargin: Tokens.spacing.extraSmall
        implicitWidth: 15
        implicitHeight: 15
        radius: Tokens.rounding.full
        color: Colours.palette.m3secondaryContainer
    }

    StyledRect {
        id: wmContainer
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Tokens.padding.large
        anchors.topMargin: Tokens.padding.small
        radius: Tokens.rounding.largeIncreased
        color: Colours.palette.m3secondaryContainer
        implicitWidth: wmLabel.implicitWidth + Tokens.padding.normal * 2
        implicitHeight: wmLabel.implicitHeight + Tokens.padding.small * 2

        Row {
            id: wmLabel
            anchors.centerIn: parent
            spacing: Tokens.spacing.extraSmall

            MaterialIcon {
                id: wmIcon
                anchors.verticalCenter: parent.verticalCenter
                text: "select_window"
                color: Colours.palette.m3onSecondaryContainer
                font.pointSize: Tokens.font.size.small
            }

            StyledText {
                id: wmText
                anchors.verticalCenter: parent.verticalCenter
                text: SysInfo.wm || qsTr("Wayland")
                color: Colours.palette.m3onSecondaryContainer
                font.pointSize: Tokens.font.size.small
                width: Math.min(implicitWidth, root.width - wmContainer.x - Tokens.padding.large - wmIcon.width - wmLabel.spacing - Tokens.padding.normal * 2)
                elide: Text.ElideRight
            }
        }
    }
}

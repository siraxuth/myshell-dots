pragma ComponentBehavior: Bound

import QtQuick
import M3Shapes as M3
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.components.filedialog
import qs.components.images
import qs.config as LocalConfig
import qs.services
import qs.utils

Item {
    id: root

    required property ScreenState screenState
    required property FileDialog facePicker

    property color pfpFallbackColour: Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)

    // Caelestia.Config also exports a `Config` type. Keep this dashboard's
    // user sizing tied to the shell's local JSON config explicitly.
    readonly property real logoSize: LocalConfig.Config.dashboard.sizes.logoSize
    readonly property real uptimeSize: LocalConfig.Config.dashboard.sizes.uptimeSize

    implicitWidth: LocalConfig.Config.dashboard.sizes.userWidth
    implicitHeight: 124
    anchors.fill: parent
    anchors.margins: Tokens.padding.large

    Behavior on pfpFallbackColour {
        CAnim {}
    }

    Item {
        id: pfpContainer

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: logoShape.right
        anchors.leftMargin: -Tokens.padding.large
        implicitWidth: height

        M3.MaterialShape {
            id: shape

            anchors.centerIn: parent
            implicitSize: parent.height
            shape: M3.MaterialShape.Pill
            color: Qt.alpha(root.pfpFallbackColour, 1)
            opacity: root.pfpFallbackColour.a
            layer.enabled: true

            MouseArea {
                id: mouse

                containmentMask: QtObject {
                    function contains(pt: point): bool {
                        return shape.contains(pt)
                            && !logoShape.contains(mouse.mapToItem(logoShape, pt))
                            && !uptimeShape.contains(mouse.mapToItem(uptimeShape, pt));
                    }
                }

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.screenState.dashboard = false;
                    root.facePicker.open();
                }
            }
        }

        Item {
            id: pfpContent

            anchors.fill: parent
            layer.enabled: true
            layer.effect: Mask {
                maskSource: shape
            }

            Loader {
                anchors.centerIn: parent
                asynchronous: true
                active: pfp.status !== Image.Ready

                sourceComponent: MaterialIcon {
                    text: "person_add"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Qt.font({ family: Tokens.font.family.material, pointSize: Tokens.font.size.extraLarge })
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
                color: Qt.alpha(Colours.palette.m3scrim, pfp.status === Image.Ready ? 0.4 : 0)
                opacity: mouse.containsMouse ? 1 : 0
                layer.enabled: opacity < 1

                Behavior on opacity {
                    Anim {
                        type: Anim.DefaultEffects
                    }
                }

                M3.MaterialShape {
                    anchors.centerIn: parent
                    implicitSize: parent.height * 0.7
                    shape: M3.MaterialShape.Diamond
                    color: Colours.palette.m3primary
                    scale: mouse.pressed ? 0.9 : mouse.containsMouse ? 1 : 0.7

                    Behavior on color {
                        CAnim {}
                    }

                    Behavior on scale {
                        Anim {
                            type: Anim.FastSpatial
                        }
                    }

                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "person_edit"
                        color: Colours.palette.m3onPrimary
                        fontStyle: Qt.font({ family: Tokens.font.family.material, pointSize: Tokens.font.size.large })
                    }
                }
            }
        }
    }

    M3.MaterialShape {
        id: logoShape

        x: Tokens.padding.small
        implicitSize: root.logoSize + Tokens.padding.small * 2
        shape: M3.MaterialShape.Gem
        color: Colours.palette.m3primaryContainer

        Behavior on color {
            CAnim {}
        }

        Loader {
            anchors.centerIn: parent
            sourceComponent: SysInfo.isDefaultLogo ? caelestiaLogo : osLogo
        }
    }

    Component {
        id: osLogo

        ColouredIcon {
            source: SysInfo.osLogo
            implicitSize: root.logoSize
            colour: Colours.palette.m3onPrimaryContainer
        }
    }

    Component {
        id: caelestiaLogo

        Logo {
            implicitWidth: root.logoSize
            implicitHeight: root.logoSize
            topColour: Colours.palette.m3primary
            bottomColour: Colours.palette.m3onPrimaryContainer
        }
    }

    M3.MaterialShape {
        id: uptimeShape

        anchors.bottom: parent.bottom
        anchors.left: pfpContainer.right
        anchors.bottomMargin: -Tokens.padding.small
        anchors.leftMargin: -Tokens.padding.large
        implicitSize: root.uptimeSize + Tokens.padding.small * 2
        shape: M3.MaterialShape.ClamShell
        color: Colours.palette.m3tertiaryContainer

        Behavior on color {
            CAnim {}
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "clock_arrow_up"
            color: Colours.palette.m3onTertiaryContainer
            fontStyle: Qt.font({ family: Tokens.font.family.material, pointSize: Tokens.font.size.normal })
        }
    }

    StyledText {
        id: uptimeText

        anchors.left: uptimeShape.right
        anchors.verticalCenter: uptimeShape.verticalCenter
        anchors.leftMargin: Tokens.spacing.small
        anchors.verticalCenterOffset: Math.round(font.pointSize * 0.1)
        text: qsTr("up %1").arg(SysInfo.uptimeShort)
        width: Math.max(0, root.width - x - Tokens.padding.large)
        elide: Text.ElideRight
    }

    StyledRect {
        id: bubble1

        anchors.left: pfpContainer.right
        anchors.top: bubble2.bottom
        anchors.leftMargin: Tokens.spacing.small
        anchors.topMargin: -Tokens.spacing.small

        implicitWidth: 10
        implicitHeight: 10
        radius: Tokens.rounding.full
        color: Colours.palette.m3secondaryContainer
    }

    StyledRect {
        id: bubble2

        anchors.left: bubble1.right
        anchors.verticalCenter: wmContainer.bottom
        anchors.leftMargin: Tokens.spacing.small

        implicitWidth: 15
        implicitHeight: 15
        radius: Tokens.rounding.full
        color: Colours.palette.m3secondaryContainer
    }

    StyledRect {
        id: wmContainer

        anchors.left: bubble2.left
        anchors.leftMargin: -Tokens.padding.small
        y: Tokens.padding.small

        radius: Tokens.rounding.large
        color: Colours.palette.m3secondaryContainer
        implicitWidth: wmLabel.implicitWidth + Tokens.padding.small * 2
        implicitHeight: wmLabel.implicitHeight + Tokens.padding.small * 2

        Row {
            id: wmLabel

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                id: wmIcon
                anchors.verticalCenter: parent.verticalCenter
                text: "select_window"
                color: Colours.palette.m3onSecondaryContainer
                font.pointSize: wmText.font.pointSize
            }

            StyledText {
                id: wmText

                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: Math.round(font.pointSize * 0.1)
                text: `${SysInfo.wm || qsTr("Wayland")}...`
                color: Colours.palette.m3onSecondaryContainer
                font.pointSize: Tokens.font.size.small
                width: Math.max(0, Math.min(implicitWidth, root.width - wmContainer.x - Tokens.padding.small * 2 - wmIcon.implicitWidth - wmLabel.spacing - Tokens.padding.large))
                elide: Text.ElideRight
            }
        }
    }
}

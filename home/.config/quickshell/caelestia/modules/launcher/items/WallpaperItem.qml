import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.components.effects
import qs.components.images
import qs.services

Item {
    id: root

    required property FileSystemEntry modelData
    required property DrawerVisibilities visibilities

    scale: 0.5
    opacity: 0
    z: PathView.z ?? 0 // qmllint disable missing-property

    property string formatIcon: Wallpapers.isVideoPath(root.modelData.path) ? "smart_display" : "image"
    property string formatText: {
        let path = String(root.modelData.path);
        let props = Wallpapers.propertiesCache[path];
        if (props) {
            let str = typeof props === "string" ? props : (props.info || "");
            let parts = str.split(", ");
            if (parts.length >= 2) return parts[1].trim();
        }
        return path.split(".").pop().toUpperCase();
    }
    property string fpsText: {
        let path = String(root.modelData.path);
        let props = Wallpapers.propertiesCache[path];
        if (props) {
            let str = typeof props === "string" ? props : (props.info || "");
            let parts = str.split(", ");
            if (parts.length === 3) return parts[2].trim();
        }
        return "";
    }
    property string resText: {
        let path = String(root.modelData.path);
        let props = Wallpapers.propertiesCache[path];
        if (props) {
            let str = typeof props === "string" ? props : (props.info || "");
            let parts = str.split(", ");
            return parts[0].trim();
        }
        let fileName = path.split("/").pop();
        return fileName.substring(0, fileName.lastIndexOf(".")) || fileName;
    }

    Component.onCompleted: {
        scale = Qt.binding(() => PathView.isCurrentItem ? 1 : PathView.onPath ? 0.8 : 0);
        opacity = Qt.binding(() => PathView.onPath ? 1 : 0);
    }

    implicitWidth: image.width + Tokens.padding.larger * 2
    implicitHeight: image.height + label.height + Tokens.spacing.small / 2 + Tokens.padding.large + Tokens.padding.normal

    StateLayer {
        radius: Tokens.rounding.normal
        onClicked: {
            if (Colours.scheme === "dynamic" && root.modelData.path !== Wallpapers.actualCurrent)
                Wallpapers.previewColourLock = true;
            Wallpapers.setWallpaper(root.modelData.path);
            root.visibilities.launcher = false;
        }
    }

    Elevation {
        anchors.fill: image
        radius: image.radius
        opacity: root.PathView.isCurrentItem ? 1 : 0
        level: 4

        Behavior on opacity {
            Anim {}
        }
    }

    StyledClippingRect {
        id: image

        anchors.horizontalCenter: parent.horizontalCenter
        y: Tokens.padding.large
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.normal

        implicitWidth: Tokens.sizes.launcher.wallpaperWidth
        implicitHeight: implicitWidth / 16 * 9

        MaterialIcon {
            anchors.centerIn: parent
            text: root.formatIcon
            color: Colours.tPalette.m3outline
            font.pointSize: Tokens.font.size.extraLarge * 2
            font.weight: 600
        }

        CachingImage {
            anchors.fill: parent
            path: {
                let pathStr = String(root.modelData.path);
                if (!pathStr) return "";
                let thumb = Wallpapers.thumbPath(pathStr);
                return thumb || pathStr;
            }
            smooth: !root.PathView.view.moving
            sourceSize: {
                const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
                return Qt.size(image.implicitWidth * dpr, image.implicitHeight * dpr);
            }
        }

        // Format badge
        StyledRect {
            z: 2
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: Tokens.spacing.smaller
            visible: root.formatText !== ""
            color: Qt.rgba(Colours.palette.m3surfaceContainer.r, Colours.palette.m3surfaceContainer.g, Colours.palette.m3surfaceContainer.b, 0.8)
            radius: Tokens.rounding.extraSmall
            implicitWidth: badgeLayout.implicitWidth + Tokens.padding.smaller * 2
            implicitHeight: badgeLayout.implicitHeight + 2

            Row {
                id: badgeLayout
                anchors.centerIn: parent
                spacing: Tokens.spacing.smaller

                MaterialIcon {
                    visible: root.formatIcon !== ""
                    text: root.formatIcon
                    font.pointSize: Tokens.font.size.smaller
                    color: Colours.palette.m3onSurface
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    visible: root.formatText !== ""
                    text: root.formatText
                    font.pointSize: Tokens.font.size.smaller
                    color: Colours.palette.m3onSurface
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // FPS badge
        StyledRect {
            z: 2
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Tokens.spacing.smaller
            visible: root.fpsText !== ""
            color: Qt.rgba(Colours.palette.m3surfaceContainer.r, Colours.palette.m3surfaceContainer.g, Colours.palette.m3surfaceContainer.b, 0.8)
            radius: Tokens.rounding.extraSmall
            implicitWidth: fpsLayout.implicitWidth + Tokens.padding.smaller * 2
            implicitHeight: fpsLayout.implicitHeight + 2

            Row {
                id: fpsLayout
                anchors.centerIn: parent
                spacing: Tokens.spacing.smaller

                MaterialIcon {
                    text: "speed"
                    font.pointSize: Tokens.font.size.smaller
                    color: Colours.palette.m3onSurface
                    anchors.verticalCenter: parent.verticalCenter
                }
                StyledText {
                    text: root.fpsText
                    font.pointSize: Tokens.font.size.smaller
                    color: Colours.palette.m3onSurface
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    StyledText {
        id: label

        anchors.top: image.bottom
        anchors.topMargin: Tokens.spacing.small / 2
        anchors.horizontalCenter: parent.horizontalCenter

        width: image.width - Tokens.padding.normal * 2
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        renderType: Text.QtRendering
        text: root.resText
        font.pointSize: Tokens.font.size.normal
    }

    Behavior on scale {
        Anim {}
    }

    Behavior on opacity {
        Anim {}
    }
}

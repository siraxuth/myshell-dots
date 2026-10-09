pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils
import QtMultimedia
import Quickshell.Services.UPower

Item {
    id: root

    property string source: Wallpapers.current
    property var current
    property bool completed
    property string previousThumb: ""

    function isVideoSource(path) {
        return typeof path === 'string' && path.match(/\.(mp4|mkv|webm|avi|mov)$/i);
    }

    function videoThumbSource(path) {
        if (!path || !isVideoSource(path)) return "";
        const parts = String(path).split("/");
        if (parts.length < 3) return "";
        const homeDir = "/" + parts[1] + "/" + parts[2];
        const fileName = parts[parts.length - 1];
        return `${homeDir}/.cache/caelestia/live_thumbs/${fileName}.jpg`;
    }

    function createMediaForSource(path, placeholderThumb) {
        if (isVideoSource(path)) {
            return videoComp.createObject(root, {
                path: path,
                thumbnailSource: placeholderThumb || videoThumbSource(path)
            });
        }
        return imgComp.createObject(root, { path: path });
    }

    onSourceChanged: {
        if (!source) {
            if (current) current.destroy();
            current = null;
            previousThumb = "";
            return;
        }

        const isVideo = isVideoSource(source);
        if (current && current.isVideo === isVideo) {
            if (isVideo) {
                previousThumb = current.thumbnailSource || videoThumbSource(current.path) || "";
                current.path = source;
                current.thumbnailSource = previousThumb;
            } else {
                current.path = source;
            }
            return;
        }

        if (current) {
            previousThumb = current.thumbnailSource || (current.isVideo ? videoThumbSource(current.path) : current.path) || "";
            current.z = 0;
            current.opacity = 1;
            current.visible = true;
        }

        const newMedia = createMediaForSource(source, previousThumb);
        newMedia.z = 1;
        newMedia.opacity = 0;
        current = newMedia;
        previousThumb = "";
    }

    Component.onCompleted: {
        completed = true;
        if (!current && source) {
            Qt.callLater(() => {
                if (!current && source)
                    current = createMediaForSource(source);
            });
        }
    }

    Loader {
        asynchronous: true
        anchors.fill: parent

        active: root.completed && !root.source

        sourceComponent: StyledRect {
            color: Colours.palette.m3surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Tokens.spacing.large

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.extraLarge * 5
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.extraLarge * 2
                        font.bold: true
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Tokens.padding.large * 2
                        implicitHeight: selectWallText.implicitHeight + Tokens.padding.small * 2

                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog

                            title: qsTr("Select a wallpaper")
                            filterLabel: qsTr("Image files")
                            filters: Images.validImageExtensions
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                            onClicked: dialog.open()
                        }

                        StyledText {
                            id: selectWallText

                            anchors.centerIn: parent

                            text: qsTr("Set it now!")
                            color: Colours.palette.m3onPrimary
                            font.pointSize: Tokens.font.size.large
                        }
                    }
                }
            }
        }
    }

    Component {
        id: videoComp

        Item {
            id: vidRoot
            property bool isVideo: true
            property string path
            property string thumbnailSource: ""
            readonly property string resolvedPlayback: {
                const cache = Wallpapers.propertiesCache;
                return path ? Wallpapers.playbackPath(path) : "";
            }
            property bool isReady: player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia || player.mediaStatus === MediaPlayer.BufferingMedia || player.playbackState === MediaPlayer.PlayingState || player.playbackState === MediaPlayer.PausedState

            anchors.fill: parent
            opacity: 0

            function beginTransition() {
                animVid.restart();
            }

            onIsReadyChanged: {
                if (isReady) {
                    thumbPreview.opacity = 0;
                    if (opacity === 0) beginTransition();
                } else if (thumbnailSource) {
                    thumbPreview.opacity = 1;
                }
            }

            MediaPlayer {
                id: player
                source: vidRoot.resolvedPlayback ? "file://" + vidRoot.resolvedPlayback : ""
                videoOutput: videoOutput
                audioOutput: null
                loops: MediaPlayer.Infinite

                property bool isCovered: {
                    try {
                        if (Wallpapers.showPreview) return false;
                        if (!Wallpapers.behaviorEnabled) return false;

                        if (Wallpapers.pauseOnGameMode && typeof GameMode !== 'undefined' && GameMode && GameMode.enabled) return true;

                        if (Wallpapers.batteryLimitEnabled && Wallpapers.batteryLimit > 0 && UPower.displayDevice && UPower.displayDevice.isPresent && UPower.displayDevice.isLaptopBattery) {
                            if (UPower.displayDevice.state === UPowerDeviceState.Discharging && (UPower.displayDevice.percentage * 100) <= Wallpapers.batteryLimit)
                                return true;
                        }

                        if (Wallpapers.pauseOnFullscreen && typeof Hypr !== 'undefined' && Hypr && Hypr.activeToplevel && Hypr.activeToplevel.lastIpcObject && Hypr.activeToplevel.lastIpcObject.fullscreen) {
                            const winClass = (Hypr.activeToplevel.lastIpcObject.class || "").toLowerCase();
                            const browsers = ["firefox", "brave", "chromium", "chrome", "zen", "thorium", "vivaldi", "opera", "floorp", "waterfox", "librewolf", "edge"];
                            if (browsers.some(b => winClass.includes(b))) return false;
                            return true;
                        }
                        return false;
                    } catch (e) { return false; }
                }

                onIsCoveredChanged: {
                    if (isCovered) player.pause();
                    else if (root.current === vidRoot) player.play();
                }

                onErrorOccurred: (error, errorString) => {
                    if (error !== MediaPlayer.NoError && vidRoot.path) {
                        let p = vidRoot.path;
                        vidRoot.path = "";
                        Qt.callLater(() => {
                            vidRoot.path = p;
                            if (!player.isCovered) player.play();
                        });
                    }
                }

                Component.onCompleted: {
                    if (!isCovered) play();
                    if (isCovered) Qt.callLater(() => { if (isCovered) pause(); });
                }
            }

            CachingImage {
                id: thumbPreview
                anchors.fill: parent
                path: vidRoot.thumbnailSource || ""
                visible: !!path && opacity > 0
                opacity: vidRoot.isReady ? 0 : 1
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                smooth: true
                Behavior on opacity {
                    NumberAnimation {
                        duration: Math.max(1, Math.min(2000, Wallpapers.animationDuration || 500))
                        easing.type: Easing.InOutCubic
                    }
                }
            }

            VideoOutput {
                id: videoOutput
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
            }

            NumberAnimation {
                id: animVid
                target: vidRoot
                property: "opacity"
                duration: Math.max(1, Math.min(2000, Wallpapers.animationDuration || 500))
                from: 0
                to: 1
                easing.type: Easing.InOutCubic
            }

            Timer {
                running: root.current !== vidRoot && root.current?.isReady
                interval: Math.max(1, Math.min(2000, Wallpapers.animationDuration || 500))
                onTriggered: {
                    player.stop();
                    player.source = "";
                    vidRoot.destroy();
                }
            }

            onPathChanged: {
                if (!path) {
                    player.stop();
                    player.source = "";
                    return;
                }

                const placeholder = root.previousThumb || root.videoThumbSource(path);
                root.previousThumb = "";
                thumbnailSource = placeholder || root.videoThumbSource(path);
                thumbPreview.opacity = 1;
                opacity = 0;

                Wallpapers.ensurePlaybackCache(path);

                if (!player.isCovered) player.play();
            }

            onResolvedPlaybackChanged: {
                if (!resolvedPlayback || !path) return;
                if (!player.isCovered) player.play();
            }
        }
    }

    Component {
        id: imgComp

        CachingImage {
            id: img

            property bool isVideo: false
            property bool isReady: status === Image.Ready

            anchors.fill: parent
            opacity: 0
            scale: Wallpapers.showPreview ? 1 : 0.8

            onStatusChanged: {
                if (status === Image.Ready)
                    root.current = this;
            }

            states: State {
                name: "visible"
                when: root.current === img

                PropertyChanges {
                    img.opacity: 1
                    img.scale: 1
                }
            }

            transitions: Transition {
                Anim {
                    target: img
                    properties: "opacity,scale"
                }
            }

            Timer {
                running: root.current !== img && root.current?.isReady
                interval: Math.max(1, Math.min(2000, Wallpapers.animationDuration || 500))
                onTriggered: {
                    img.source = "";
                    img.destroy();
                }
            }
        }
    }
}

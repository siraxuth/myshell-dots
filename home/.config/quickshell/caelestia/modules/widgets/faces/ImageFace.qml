pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services

Item {
    id: root

    required property var widget
    property string reportedSource: ""

    signal naturalSizeChanged(real imageWidth, real imageHeight)

    readonly property real cornerRadius: {
        const configured = Number(widget.wProps?.bgRadius);
        if (widget.wProps?.bgRadius !== undefined && Number.isFinite(configured))
            return Math.max(0, Math.min(configured, Math.min(width, height) / 2));
        if (widget.wVariant === "round") return Math.min(width, height) / 2;
        if (widget.wVariant === "rounded") return 22;
        return 0;
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "#20212a"
        clip: true

        Image {
            id: image
            anchors.fill: parent
            source: WidgetsPrefs.normalizeImagePath(root.widget.wImagePath)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            // Widget images may be very large originals and are not shared across the UI.
            // Avoid retaining old decoded versions when the user changes the path.
            cache: false
            smooth: true
            sourceSize: {
                const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
                return Qt.size(Math.max(1, width * dpr), Math.max(1, height * dpr));
            }
            visible: status === Image.Ready
            onStatusChanged: if (status === Image.Ready) naturalSizeTimer.restart()
        }

        Timer {
            id: naturalSizeTimer
            interval: 1
            repeat: false
            onTriggered: {
                if (image.status !== Image.Ready || image.source === root.reportedSource) return;
                const naturalWidth = image.sourceSize.width || image.implicitWidth;
                const naturalHeight = image.sourceSize.height || image.implicitHeight;
                if (naturalWidth <= 0 || naturalHeight <= 0) return;
                root.reportedSource = image.source;
                root.naturalSizeChanged(naturalWidth, naturalHeight);
            }
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - 24
            text: root.widget.wImagePath
                ? qsTr("Image could not be loaded")
                : qsTr("Set an image path in the inspector")
            color: "#e6e1e5"
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: !root.widget.wImagePath || image.status === Image.Error
        }

    }
}

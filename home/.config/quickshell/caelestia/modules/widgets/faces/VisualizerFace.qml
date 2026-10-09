pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.services

Item {
    id: root

    required property var widget

    ServiceRef { service: Audio.cava }

    Row {
        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        spacing: 3
        visible: root.widget.wVariant !== "continuous"
        Repeater {
            model: Audio.cava.values
            Rectangle {
                required property real modelData
                Layout.fillWidth: true
                width: Math.max(2, (parent.width - (Audio.cava.values.length - 1) * 3) / Math.max(1, Audio.cava.values.length))
                height: Math.max(4, parent.height * Math.max(0.05, modelData))
                anchors.bottom: parent.bottom
                radius: root.widget.wVariant === "continuous" ? height / 2 : Tokens.rounding.small
                color: Colours.palette.m3primary
                Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
            }
        }
    }

    Canvas {
        id: waveform
        anchors.fill: parent
        anchors.margins: Tokens.padding.small
        visible: root.widget.wVariant === "continuous"
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const values = Audio.cava.values;
            if (!values || values.length < 2) return;
            ctx.beginPath();
            ctx.lineWidth = Math.max(2, height * 0.035);
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.strokeStyle = Colours.palette.m3primary;
            for (let i = 0; i < values.length; i++) {
                const x = i * width / (values.length - 1);
                const y = height * (1 - Math.max(0, Math.min(1, Number(values[i]))));
                if (i === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.stroke();
        }
        Connections {
            target: Audio.cava
            function onValuesChanged() { waveform.requestPaint(); }
        }
    }
}

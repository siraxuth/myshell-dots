pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    property bool bgVisible: true
    property string variant: "compact"

    implicitWidth: layout.implicitWidth + Tokens.padding.large * 2
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2
    radius: variant === "round" ? Math.min(width, height) / 2 : Tokens.rounding.large
    color: "transparent"

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.normal
            MaterialIcon {
                text: Weather.icon
                color: Colours.palette.m3primary
                font.pointSize: root.variant === "round" ? Tokens.font.size.extraLarge * 2.2 : Tokens.font.size.extraLarge * 1.6
                fill: 1
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: Weather.temp
                    font.bold: true
                    font.pointSize: Tokens.font.size.large
                    color: Colours.palette.m3onSurface
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Weather.description
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: root.variant !== "compact" && !!Weather.city
                    text: Weather.city
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.small
                    elide: Text.ElideRight
                }
            }
            Item { Layout.fillWidth: true }
            ColumnLayout {
                visible: root.variant === "full"
                StyledText { Layout.fillWidth: true; text: qsTr("Feels like %1").arg(Weather.feelsLike); color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.font.size.small; elide: Text.ElideRight }
                StyledText { Layout.fillWidth: true; text: qsTr("Humidity %1%").arg(Weather.humidity); color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.font.size.small; elide: Text.ElideRight }
                StyledText { Layout.fillWidth: true; text: qsTr("Wind %1 km/h").arg(Math.round(Weather.windSpeed)); color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.font.size.small; elide: Text.ElideRight }
            }
        }

        RowLayout {
            visible: root.variant === "full"
            Layout.fillWidth: true
            spacing: Tokens.spacing.normal
            Repeater {
                model: Weather.hourlyForecast.slice(0, 4)
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: `${String(modelData.hour).padStart(2, "0")}:00`
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.small
                    }
                    MaterialIcon { Layout.alignment: Qt.AlignHCenter; text: parent.modelData.icon; color: Colours.palette.m3primary }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: GlobalConfig.services.useFahrenheit ? `${modelData.tempF}°` : `${modelData.tempC}°`
                        color: Colours.palette.m3onSurface
                        font.pointSize: Tokens.font.size.small
                    }
                }
            }
        }
    }
}

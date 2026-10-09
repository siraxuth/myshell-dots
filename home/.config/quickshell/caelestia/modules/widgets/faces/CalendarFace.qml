pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    property date viewDate: new Date()
    property date selectedDate: new Date()

    readonly property int viewMonth: viewDate.getMonth()
    readonly property int viewYear: viewDate.getFullYear()
    readonly property string selectedDateKey: Events.formatDateKey(selectedDate)
    readonly property var rangeLanes: {
        const ranges = Events.getRangesForMonth(viewYear, viewMonth).slice().sort((a, b) => a.startDate.localeCompare(b.startDate) || String(a.id).localeCompare(String(b.id)));
        const laneEndDates = [];
        const lanes = {};
        for (const range of ranges) {
            let lane = laneEndDates.findIndex(endDate => endDate < range.startDate);
            if (lane < 0)
                lane = laneEndDates.length;
            laneEndDates[lane] = range.endDate;
            lanes[String(range.id)] = lane;
        }
        return lanes;
    }
    readonly property var selectedEvents: {
        const eventIndex = Events.rangeIndex;
        return Events.getEvents(selectedDateKey);
    }

    function moveMonth(amount: int): void {
        const nextMonth = new Date(viewYear, viewMonth + amount, 1);
        const lastDay = new Date(nextMonth.getFullYear(), nextMonth.getMonth() + 1, 0).getDate();
        viewDate = nextMonth;
        selectedDate = new Date(nextMonth.getFullYear(), nextMonth.getMonth(), Math.min(selectedDate.getDate(), lastDay));
    }

    StyledRect {
        anchors.fill: parent
        color: "transparent"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    StyledText {
                        text: qsTr("CALENDAR")
                        color: Colours.palette.m3primary
                        font.pointSize: Tokens.font.size.smaller
                        font.weight: 700
                        font.letterSpacing: 1.1
                    }

                    StyledText {
                        text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                        color: Colours.palette.m3onSurface
                        font.pointSize: Tokens.font.size.large
                        font.weight: 600
                        font.capitalization: Font.Capitalize
                    }
                }

                Item {
                    implicitWidth: 34
                    implicitHeight: 34
                    StateLayer {
                        radius: Tokens.rounding.full
                        onClicked: root.moveMonth(-1)
                    }
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "chevron_left"
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.normal
                    }
                }

                Item {
                    implicitWidth: 34
                    implicitHeight: 34
                    StateLayer {
                        radius: Tokens.rounding.full
                        onClicked: root.moveMonth(1)
                    }
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "chevron_right"
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.normal
                    }
                }
            }

            DayOfWeekRow {
                Layout.fillWidth: true
                locale: Qt.locale()
                delegate: StyledText {
                    required property var model
                    horizontalAlignment: Text.AlignHCenter
                    text: model.shortName.substring(0, 1)
                    color: Colours.palette.m3outline
                    font.pointSize: Tokens.font.size.smaller
                    font.weight: 600
                }
            }

            MonthGrid {
                id: monthGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                month: root.viewMonth
                year: root.viewYear
                locale: Qt.locale()
                spacing: 2

                delegate: Item {
                    id: dayCell
                    required property var model

                    readonly property string dayKey: Events.formatDateKey(model.date)
                    readonly property bool selected: dayKey === root.selectedDateKey
                    readonly property var dayEvents: Events.getEvents(dayKey)
                    readonly property var rangeEvents: dayEvents.filter(evt => evt?.endDate && evt.endDate > evt.date && root.rangeLanes[String(evt.id)] < 2).slice().sort((a, b) => root.rangeLanes[String(a.id)] - root.rangeLanes[String(b.id)])
                    readonly property var singleEvents: dayEvents.filter(evt => !evt?.endDate || evt.endDate <= evt.date)

                    implicitWidth: 34
                    implicitHeight: 34

                    StyledRect {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height)
                        height: width
                        radius: Tokens.rounding.full
                        color: dayCell.selected ? Colours.palette.m3primary : dayCell.model.today ? Colours.palette.m3tertiaryContainer : "transparent"
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: dayCell.model.day
                        color: dayCell.selected ? Colours.palette.m3onPrimary : dayCell.model.month === monthGrid.month ? Colours.palette.m3onSurface : Colours.palette.m3outline
                        font.pointSize: Tokens.font.size.small
                        font.weight: dayCell.selected || dayCell.model.today ? 700 : 400
                    }

                    StyledRect {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        width: 4
                        height: 4
                        radius: Tokens.rounding.full
                        color: dayCell.selected ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                        visible: dayCell.singleEvents.length > 0
                    }

                    Repeater {
                        model: dayCell.rangeEvents.slice(0, 2)

                        delegate: Shape {
                            id: eventWave
                            required property var modelData

                            readonly property bool continuesBefore: modelData.date < dayCell.dayKey
                            readonly property bool continuesAfter: modelData.endDate > dayCell.dayKey
                            readonly property int lane: root.rangeLanes[String(modelData.id)]
                            readonly property int eventColor: {
                                let hash = 0;
                                const eventId = String(modelData.id ?? "");
                                for (let i = 0; i < eventId.length; ++i)
                                    hash = (hash * 31 + eventId.charCodeAt(i)) >>> 0;
                                return hash % 3;
                            }

                            x: continuesBefore ? -2 : parent.width / 2
                            y: parent.height - 10 + lane * 3
                            width: Math.max(4, (continuesAfter ? parent.width + 2 : parent.width / 2) - x)
                            height: 8
                            z: 2
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeWidth: 2
                                strokeColor: eventWave.eventColor === 0 ? Colours.palette.m3primary : eventWave.eventColor === 1 ? Colours.palette.m3tertiary : Colours.palette.m3secondary
                                fillColor: "transparent"
                                capStyle: ShapePath.RoundCap
                                joinStyle: ShapePath.RoundJoin
                                startX: 0
                                startY: 4
                                PathCubic {
                                    x: eventWave.width / 2
                                    y: 4
                                    control1X: eventWave.width / 4
                                    control1Y: 0
                                    control2X: eventWave.width / 4
                                    control2Y: 8
                                }
                                PathCubic {
                                    x: eventWave.width
                                    y: 4
                                    control1X: eventWave.width * 3 / 4
                                    control1Y: 0
                                    control2X: eventWave.width * 3 / 4
                                    control2Y: 8
                                }
                            }
                        }
                    }

                    StateLayer {
                        anchors.fill: parent
                        radius: Tokens.rounding.full
                        onClicked: root.selectedDate = dayCell.model.date
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Colours.layer(Colours.palette.m3outlineVariant, 1)
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledRect {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 3
                    implicitHeight: Math.max(18, selectedDateLabel.implicitHeight)
                    radius: Tokens.rounding.full
                    color: Colours.palette.m3primary
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        id: selectedDateLabel
                        Layout.fillWidth: true
                        text: Qt.formatDate(root.selectedDate, "ddd, d MMM")
                        color: Colours.palette.m3onSurface
                        font.pointSize: Tokens.font.size.small
                        font.weight: 600
                        font.capitalization: Font.Capitalize
                    }

                    StyledText {
                        Layout.fillWidth: true
                        visible: root.selectedEvents.length === 0
                        text: qsTr("Nothing planned")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.smaller
                        elide: Text.ElideRight
                    }

                    Repeater {
                        model: root.selectedEvents.slice(0, 2)
                        delegate: StyledText {
                            required property var modelData
                            Layout.fillWidth: true
                            text: [modelData.time, modelData.title].filter(value => value && String(value).trim()).join(" · ")
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Tokens.font.size.smaller
                            elide: Text.ElideRight
                        }
                    }
                }

                StyledText {
                    visible: root.selectedEvents.length > 2
                    text: `+${root.selectedEvents.length - 2}`
                    color: Colours.palette.m3primary
                    font.pointSize: Tokens.font.size.smaller
                    font.weight: 600
                }
            }
        }
    }
}

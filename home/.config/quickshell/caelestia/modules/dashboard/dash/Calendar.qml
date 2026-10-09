pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services

CustomMouseArea {
    id: root

    required property DashboardState dashState

    readonly property int currMonth: dashState.currentDate.getMonth()
    readonly property int currYear: dashState.currentDate.getFullYear()
    readonly property string selectedDateKey: Events.formatDateKey(dashState.currentDate)
    readonly property var selectedEvents: Events.getEvents(selectedDateKey)

    function onWheel(event: WheelEvent): void {
        if (event.angleDelta.y > 0)
            root.dashState.currentDate = new Date(root.currYear, root.currMonth - 1, 1);
        else if (event.angleDelta.y < 0)
            root.dashState.currentDate = new Date(root.currYear, root.currMonth + 1, 1);
    }

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: inner.implicitHeight + inner.anchors.margins * 2

    acceptedButtons: Qt.MiddleButton
    onClicked: root.dashState.currentDate = new Date()

    ColumnLayout {
        id: inner

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.small

        RowLayout {
            id: monthNavigationRow

            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Item {
                implicitWidth: implicitHeight
                implicitHeight: prevMonthText.implicitHeight + Tokens.padding.small * 2

                StateLayer {
                    id: prevMonthStateLayer

                    radius: Tokens.rounding.full
                    onClicked: root.dashState.currentDate = new Date(root.currYear, root.currMonth - 1, 1)
                }

                MaterialIcon {
                    id: prevMonthText

                    anchors.centerIn: parent
                    text: "chevron_left"
                    color: Colours.palette.m3tertiary
                    font.pointSize: Tokens.font.size.normal
                    font.weight: 700
                }
            }

            Item {
                Layout.fillWidth: true

                implicitWidth: monthYearDisplay.implicitWidth + Tokens.padding.small * 2
                implicitHeight: monthYearDisplay.implicitHeight + Tokens.padding.small * 2

                StateLayer {
                    onClicked: {
                        root.dashState.currentDate = new Date();
                    }

                    anchors.fill: monthYearDisplay
                    anchors.margins: -Tokens.padding.small
                    anchors.leftMargin: -Tokens.padding.normal
                    anchors.rightMargin: -Tokens.padding.normal

                    radius: Tokens.rounding.full
                    disabled: {
                        const now = new Date();
                        return root.currMonth === now.getMonth() && root.currYear === now.getFullYear();
                    }
                }

                StyledText {
                    id: monthYearDisplay

                    anchors.centerIn: parent
                    text: grid.title
                    color: Colours.palette.m3primary
                    font.pointSize: Tokens.font.size.normal
                    font.weight: 500
                    font.capitalization: Font.Capitalize
                }
            }

            Item {
                implicitWidth: implicitHeight
                implicitHeight: nextMonthText.implicitHeight + Tokens.padding.small * 2

                StateLayer {
                    id: nextMonthStateLayer

                    onClicked: {
                        root.dashState.currentDate = new Date(root.currYear, root.currMonth + 1, 1);
                    }

                    radius: Tokens.rounding.full
                }

                MaterialIcon {
                    id: nextMonthText

                    anchors.centerIn: parent
                    text: "chevron_right"
                    color: Colours.palette.m3tertiary
                    font.pointSize: Tokens.font.size.normal
                    font.weight: 700
                }
            }
        }

        DayOfWeekRow {
            id: daysRow

            Layout.fillWidth: true
            locale: grid.locale

            delegate: StyledText {
                required property var model

                horizontalAlignment: Text.AlignHCenter
                text: model.shortName
                font.weight: 500
                color: (model.day === 0 || model.day === 6 || model.day === 7) ? Colours.palette.m3secondary : Colours.palette.m3onSurfaceVariant
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: grid.implicitHeight

            MonthGrid {
                id: grid

                month: root.currMonth
                year: root.currYear

                anchors.fill: parent

                spacing: 3
                locale: Qt.locale()

                delegate: Item {
                    id: dayItem

                    required property var model
                    readonly property bool hasEvents: Events.hasEvents(Events.formatDateKey(dayItem.model.date))
                    readonly property bool selected: Events.formatDateKey(dayItem.model.date) === root.selectedDateKey

                    implicitWidth: implicitHeight
                    implicitHeight: text.implicitHeight + Tokens.padding.small * 2 + 6

                    StyledRect {
                        anchors.fill: parent
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary
                        opacity: dayItem.selected && !dayItem.model.today ? 0.2 : 0
                    }

                    StateLayer {
                        anchors.fill: parent
                        radius: Tokens.rounding.full
                        onClicked: root.dashState.currentDate = dayItem.model.date
                    }

                    StyledText {
                        id: text

                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: dayItem.hasEvents ? -2 : 0

                        horizontalAlignment: Text.AlignHCenter
                        text: grid.locale.toString(dayItem.model.day)
                        color: {
                            const dayOfWeek = dayItem.model.date.getUTCDay();
                            if (dayOfWeek === 0 || dayOfWeek === 6)
                                return Colours.palette.m3secondary;

                            return Colours.palette.m3onSurfaceVariant;
                        }
                        opacity: dayItem.model.today || dayItem.model.month === grid.month ? 1 : 0.4
                        font.pointSize: Tokens.font.size.normal
                        font.weight: 500
                    }

                    StyledRect {
                        visible: dayItem.hasEvents
                        anchors.top: text.bottom
                        anchors.topMargin: 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 4
                        height: 4
                        radius: Tokens.rounding.full
                        color: dayItem.model.today ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                        opacity: dayItem.model.month === grid.month ? 1 : 0.4
                    }
                }
            }

            StyledRect {
                id: todayIndicator

                readonly property Item todayItem: grid.contentItem.children.find(c => c.model.today) ?? null
                property Item today

                onTodayItemChanged: {
                    if (todayItem)
                        today = todayItem;
                }

                x: today ? today.x + (today.width - implicitWidth) / 2 : 0
                y: today?.y ?? 0

                implicitWidth: today?.implicitWidth ?? 0
                implicitHeight: today?.implicitHeight ?? 0

                clip: true
                radius: Tokens.rounding.full
                color: Colours.palette.m3primary

                opacity: todayItem ? 1 : 0
                scale: todayItem ? 1 : 0.7

                Colouriser {
                    x: -todayIndicator.x
                    y: -todayIndicator.y

                    implicitWidth: grid.width
                    implicitHeight: grid.height

                    source: grid
                    sourceColor: Colours.palette.m3onSurface
                    colorizationColor: Colours.palette.m3onPrimary
                }

                Behavior on opacity {
                    Anim {}
                }

                Behavior on scale {
                    Anim {}
                }

                Behavior on x {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }

                Behavior on y {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small
            visible: root.selectedEvents.length > 0

            StyledText {
                Layout.fillWidth: true
                text: Qt.formatDate(root.dashState.currentDate, "dddd, d MMMM")
                color: Colours.palette.m3primary
                font.pointSize: Tokens.font.size.small
                font.weight: 600
                font.capitalization: Font.Capitalize
            }

            Repeater {
                model: root.selectedEvents

                delegate: RowLayout {
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledRect {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: Tokens.padding.smaller
                        implicitWidth: 3
                        implicitHeight: title.implicitHeight + (description.visible ? description.implicitHeight + 2 : 0)
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            id: title
                            Layout.fillWidth: true
                            text: [modelData.time, modelData.title].filter(value => value && String(value).trim()).join(" · ")
                            color: Colours.palette.m3onSurface
                            font.pointSize: Tokens.font.size.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            id: description
                            Layout.fillWidth: true
                            visible: Boolean(modelData.description)
                            text: modelData.description ?? ""
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Tokens.font.size.smaller
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }
            }
        }
    }
}

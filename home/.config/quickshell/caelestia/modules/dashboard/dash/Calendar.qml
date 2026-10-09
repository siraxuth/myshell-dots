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
    readonly property var rangeLanes: {
        const ranges = Events.getRangesForMonth(currYear, currMonth).slice().sort((a, b) => a.startDate.localeCompare(b.startDate) || String(a.id).localeCompare(String(b.id)));
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
    property bool eventFormOpen: false
    property string editingEventId: ""
    property var lastDeletedEvent: null
    property string formError: ""
    property string formStartDate: ""
    property string formEndDate: ""
    property date dragStartDate: new Date()
    property date rangeAnchorDate: new Date()
    property bool draggingDates: false
    property bool rangePickPending: false
    property bool dateRangeSelected: false

    function validDateKey(value: string): string {
        const key = Events.formatDateKey(value);
        if (!key)
            return "";
        const parts = key.split("-").map(Number);
        const date = new Date(parts[0], parts[1] - 1, parts[2]);
        return date.getFullYear() === parts[0] && date.getMonth() === parts[1] - 1 && date.getDate() === parts[2] ? key : "";
    }

    function dateAtPosition(x: real, y: real): var {
        const content = grid.contentItem;
        if (!content)
            return null;
        const point = dateDragArea.mapToItem(content, x, y);
        for (const child of content.children) {
            if (!child.model?.date)
                continue;
            if (point.x >= child.x && point.x < child.x + child.width && point.y >= child.y && point.y < child.y + child.height)
                return child.model.date;
        }
        return null;
    }

    function selectFormDate(start: var, end: var): void {
        let startKey = Events.formatDateKey(start);
        let endKey = end ? Events.formatDateKey(end) : "";
        if (endKey && endKey < startKey) {
            const swap = startKey;
            startKey = endKey;
            endKey = swap;
        }
        formStartDate = startKey;
        formEndDate = endKey === startKey ? "" : endKey;
        dateRangeSelected = formEndDate !== "";
        dashState.currentDate = end ?? start;
    }

    function beginAddEvent(): void {
        editingEventId = "";
        formError = "";
        titleInput.text = "";
        timeInput.text = "";
        if (!rangePickPending && !dateRangeSelected) {
            formStartDate = selectedDateKey;
            formEndDate = "";
        }
        descriptionInput.text = "";
        eventFormOpen = true;
        Qt.callLater(() => titleInput.forceActiveFocus());
    }

    function beginEditEvent(evt: var): void {
        if (!evt)
            return;
        editingEventId = String(evt.id);
        formError = "";
        rangePickPending = false;
        dateRangeSelected = false;
        titleInput.text = evt.title ?? "";
        timeInput.text = evt.time ?? "";
        formStartDate = evt.date ?? selectedDateKey;
        formEndDate = evt.endDate ?? "";
        descriptionInput.text = evt.description ?? "";
        eventFormOpen = true;
        Qt.callLater(() => titleInput.forceActiveFocus());
    }

    function saveEvent(): void {
        const title = titleInput.text.trim();
        const startDate = validDateKey(formStartDate);
        const endDate = formEndDate ? validDateKey(formEndDate) : "";
        if (!title) {
            formError = qsTr("Enter an event title.");
            return;
        }
        if (!startDate || (formEndDate && !endDate)) {
            formError = qsTr("Choose a valid date on the calendar.");
            return;
        }
        if (editingEventId)
            Events.updateEvent(editingEventId, timeInput.text.trim(), title, descriptionInput.text.trim(), startDate, endDate);
        else
            Events.addEvent(startDate, timeInput.text.trim(), title, descriptionInput.text.trim(), endDate);
        eventFormOpen = false;
        editingEventId = "";
        formError = "";
        formEndDate = "";
        rangePickPending = false;
        dateRangeSelected = false;
    }

    function deleteEvent(evt: var): void {
        if (!evt)
            return;
        lastDeletedEvent = evt;
        undoTimer.restart();
        Events.deleteEvent(evt.id);
        if (editingEventId === String(evt.id)) {
            eventFormOpen = false;
            editingEventId = "";
        }
    }

    function undoDelete(): void {
        if (!lastDeletedEvent)
            return;
        Events.restoreEvent(lastDeletedEvent);
        lastDeletedEvent = null;
        undoTimer.stop();
    }

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

    Timer {
        id: undoTimer
        interval: 5000
        onTriggered: root.lastDeletedEvent = null
    }

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
                    onClicked: {
                        if (!root.rangePickPending)
                            root.dateRangeSelected = false;
                        root.dashState.currentDate = new Date(root.currYear, root.currMonth - 1, 1);
                    }
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
                        if (!root.rangePickPending)
                            root.dateRangeSelected = false;
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
                        if (!root.rangePickPending)
                            root.dateRangeSelected = false;
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
                    readonly property var dayEvents: Events.getEvents(Events.formatDateKey(dayItem.model.date))
                    readonly property var rangeEvents: dayItem.dayEvents.filter(evt => evt && evt.endDate && evt.endDate > evt.date && root.rangeLanes[String(evt.id)] < 2).slice().sort((a, b) => root.rangeLanes[String(a.id)] - root.rangeLanes[String(b.id)])
                    readonly property var singleEvents: dayItem.dayEvents.filter(evt => !evt?.endDate || evt.endDate <= evt.date)
                    readonly property bool selected: Events.formatDateKey(dayItem.model.date) === root.selectedDateKey
                    readonly property string dayKey: Events.formatDateKey(dayItem.model.date)
                    readonly property bool inFormRange: root.formStartDate !== "" && dayItem.dayKey >= root.formStartDate && dayItem.dayKey <= (root.formEndDate || root.formStartDate) && (root.eventFormOpen || root.rangePickPending || root.formEndDate !== "")

                    implicitWidth: implicitHeight
                    implicitHeight: text.implicitHeight + Tokens.padding.small * 2 + 6 + Math.min(2, dayItem.rangeEvents.length) * 4

                    StyledRect {
                        anchors.fill: parent
                        radius: Tokens.rounding.full
                        color: dayItem.inFormRange ? Colours.palette.m3tertiary : Colours.palette.m3primary
                        opacity: dayItem.inFormRange ? 0.22 : dayItem.selected && !dayItem.model.today ? 0.2 : 0
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

                    Repeater {
                        model: dayItem.rangeEvents.slice(0, 2)

                        delegate: StyledRect {
                            required property var modelData
                            required property int index
                            readonly property string dayKey: Events.formatDateKey(dayItem.model.date)
                            readonly property bool continuesBefore: modelData.date < dayKey
                            readonly property bool continuesAfter: modelData.endDate > dayKey
                            readonly property int colorKey: {
                                let hash = 0;
                                const id = String(modelData.id ?? "");
                                for (let i = 0; i < id.length; i++)
                                    hash = (hash * 31 + id.charCodeAt(i)) >>> 0;
                                return hash % 3;
                            }

                            x: continuesBefore ? -2 : parent.width / 2
                            width: Math.max(3, (continuesAfter ? parent.width + 2 : parent.width / 2) - x)
                            y: text.y + text.height + 2 + index * 4
                            height: 3
                            radius: Tokens.rounding.full
                            color: colorKey === 0 ? Colours.palette.m3primary : colorKey === 1 ? Colours.palette.m3tertiary : Colours.palette.m3secondary
                            opacity: dayItem.model.month === grid.month ? 1 : 0.4
                            z: 2
                        }
                    }

                    Row {
                        anchors.top: text.bottom
                        anchors.topMargin: 2 + Math.min(2, dayItem.rangeEvents.length) * 4
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 2
                        visible: dayItem.singleEvents.length > 0

                        Repeater {
                            model: Math.min(dayItem.singleEvents.length, 3)

                            StyledRect {
                                width: 4
                                height: 4
                                radius: Tokens.rounding.full
                                color: dayItem.model.today ? Colours.palette.m3onPrimary : Colours.palette.m3primary
                                opacity: dayItem.model.month === grid.month ? 1 : 0.4
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: dateDragArea
                anchors.fill: grid
                z: 5
                acceptedButtons: Qt.LeftButton
                preventStealing: true

                onPressed: mouse => {
                    const date = root.dateAtPosition(mouse.x, mouse.y);
                    if (!date)
                        return;
                    root.dragStartDate = date;
                    root.draggingDates = false;
                }

                onPositionChanged: mouse => {
                    if (!(mouse.buttons & Qt.LeftButton))
                        return;
                    const date = root.dateAtPosition(mouse.x, mouse.y);
                    if (!date || Events.formatDateKey(date) === Events.formatDateKey(root.dragStartDate))
                        return;
                    root.draggingDates = true;
                    root.selectFormDate(root.dragStartDate, date);
                    root.rangePickPending = false;
                }

                onReleased: mouse => {
                    const date = root.dateAtPosition(mouse.x, mouse.y);
                    if (date) {
                        if (root.draggingDates) {
                            root.selectFormDate(root.dragStartDate, date);
                            root.rangePickPending = false;
                        } else if (root.rangePickPending) {
                            root.selectFormDate(root.rangeAnchorDate, date);
                            root.rangePickPending = false;
                        } else {
                            root.rangeAnchorDate = date;
                            root.selectFormDate(date, null);
                            root.rangePickPending = true;
                        }
                    }
                    root.draggingDates = false;
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
            visible: true

            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    text: Qt.formatDate(root.dashState.currentDate, "dddd, d MMMM")
                    color: Colours.palette.m3primary
                    font.pointSize: Tokens.font.size.small
                    font.weight: 600
                    font.capitalization: Font.Capitalize
                }

                TextButton {
                    text: qsTr("Add event")
                    onClicked: root.beginAddEvent()
                }
            }

            StyledClippingRect {
                id: eventFormCard
                Layout.fillWidth: true
                implicitHeight: formContent.implicitHeight + Tokens.padding.normal * 2
                visible: root.eventFormOpen
                radius: Tokens.rounding.large
                color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                ColumnLayout {
                    id: formContent
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.normal
                    spacing: Tokens.spacing.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small
                        StyledTextField {
                            id: titleInput
                            Layout.fillWidth: true
                            placeholderText: qsTr("Event title")
                            background: StyledRect { color: Colours.layer(Colours.palette.m3surfaceContainer, 2); radius: Tokens.rounding.normal }
                        }
                        IconButton {
                            icon: "close"
                            Accessible.name: qsTr("Cancel event edit")
                            onClicked: { root.eventFormOpen = false; root.editingEventId = ""; root.formError = ""; }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small
                        StyledText {
                            Layout.fillWidth: true
                            text: root.formEndDate ? qsTr("%1 – %2 · select dates on calendar").arg(root.formStartDate).arg(root.formEndDate) : root.rangePickPending ? qsTr("%1 · select the end date").arg(root.formStartDate) : qsTr("%1 · click or drag dates on calendar").arg(root.formStartDate)
                            color: Colours.palette.m3onSurfaceVariant
                            font.pointSize: Tokens.font.size.smaller
                            elide: Text.ElideRight
                        }
                        StyledTextField {
                            id: timeInput
                            Layout.preferredWidth: 82
                            placeholderText: qsTr("Time")
                            background: StyledRect { color: Colours.layer(Colours.palette.m3surfaceContainer, 2); radius: Tokens.rounding.normal }
                        }
                    }

                    StyledTextField {
                        id: descriptionInput
                        Layout.fillWidth: true
                        placeholderText: qsTr("Description · optional")
                        background: StyledRect { color: Colours.layer(Colours.palette.m3surfaceContainer, 2); radius: Tokens.rounding.normal }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            visible: root.formError.length > 0
                            text: root.formError
                            color: Colours.palette.m3error
                            font.pointSize: Tokens.font.size.small
                        }
                        TextButton { text: qsTr("Cancel"); onClicked: { root.eventFormOpen = false; root.editingEventId = ""; root.formError = ""; } }
                        TextButton { text: root.editingEventId ? qsTr("Save changes") : qsTr("Save event"); onClicked: root.saveEvent() }
                    }
                }
            }

            Repeater {
                model: root.eventFormOpen ? [] : root.selectedEvents

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

                    IconButton {
                        icon: "edit"
                        Accessible.name: qsTr("Edit event")
                        onClicked: root.beginEditEvent(modelData)
                    }

                    IconButton {
                        icon: "delete"
                        Accessible.name: qsTr("Delete event")
                        inactiveOnColour: Colours.palette.m3error
                        onClicked: root.deleteEvent(modelData)
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: root.lastDeletedEvent !== null
                StyledText { Layout.fillWidth: true; text: qsTr("Event deleted"); color: Colours.palette.m3onSurfaceVariant; font.pointSize: Tokens.font.size.small }
                TextButton { text: qsTr("Undo"); onClicked: root.undoDelete() }
                IconButton { icon: "close"; Accessible.name: qsTr("Dismiss undo"); onClicked: { undoTimer.stop(); root.lastDeletedEvent = null; } }
            }

            StyledText {
                Layout.fillWidth: true
                visible: !root.eventFormOpen && root.selectedEvents.length === 0
                text: qsTr("No events for this date.")
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
            }
        }
    }
}

pragma ComponentBehavior: Bound

import "../components"
import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.modules.settings
import qs.services

Item {
    id: root

    required property Session session
    property string editingId: ""
    property string pendingDeleteId: ""

    readonly property var allEvents: {
        const entries = [];
        for (const key in Events.eventsData) {
            const day = Events.eventsData[key];
            if (Array.isArray(day))
                entries.push(...day);
        }
        return entries.sort((a, b) => `${a.date} ${a.time || ""}`.localeCompare(`${b.date} ${b.time || ""}`));
    }

    function clearForm(): void {
        editingId = "";
        pendingDeleteId = "";
        dateField.text = Events.formatDateKey(new Date());
        endDateField.text = "";
        timeField.text = "";
        titleField.text = "";
        descriptionField.text = "";
    }

    function validDate(value: string): string {
        const key = Events.formatDateKey(value);
        if (!key)
            return "";
        const parsed = new Date(`${key}T12:00:00`);
        return !isNaN(parsed.getTime()) && Events.formatDateKey(parsed) === key ? key : "";
    }

    function saveEvent(): void {
        const title = titleField.text.trim();
        const start = validDate(dateField.text);
        const end = endDateField.text.trim() ? validDate(endDateField.text) : "";
        if (!title || !start || (endDateField.text.trim() && !end))
            return;

        if (editingId) {
            Events.updateEvent(editingId, timeField.text.trim(), title, descriptionField.text.trim(), start, end);
        } else {
            Events.addEvent(start, timeField.text.trim(), title, descriptionField.text.trim(), end);
        }
        clearForm();
    }

    PaneFrame {
        anchors.fill: parent

        Flickable {
            id: page
            anchors.fill: parent
            contentWidth: width
            contentHeight: content.implicitHeight
            clip: true
            flickableDirection: Flickable.VerticalFlick
            SettingsScrollHandler { flickable: page }

            ColumnLayout {
                id: content
                width: page.width
                spacing: Tokens.spacing.normal

                SettingsHeader {
                    icon: "event"
                    title: qsTr("Calendar events")
                }

                SectionHeader {
                    title: qsTr("Add or edit an event")
                    description: qsTr("Changes are saved to your calendar and appear in the desktop calendar.")
                }

                SectionContainer {
                    Layout.fillWidth: true

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width > 700 ? 2 : 1
                        columnSpacing: Tokens.spacing.normal
                        rowSpacing: Tokens.spacing.small

                        StyledTextField {
                            id: dateField
                            Layout.fillWidth: true
                            placeholderText: qsTr("Start date · YYYY-MM-DD")
                            text: Events.formatDateKey(new Date())
                            Accessible.name: qsTr("Event start date")
                        }
                        StyledTextField {
                            id: endDateField
                            Layout.fillWidth: true
                            placeholderText: qsTr("End date · optional")
                            Accessible.name: qsTr("Event end date, optional")
                        }
                        StyledTextField {
                            id: timeField
                            Layout.fillWidth: true
                            placeholderText: qsTr("Time · optional")
                            Accessible.name: qsTr("Event time, optional")
                        }
                        StyledTextField {
                            id: titleField
                            Layout.fillWidth: true
                            placeholderText: qsTr("Event title")
                            maximumLength: 200
                            Accessible.name: qsTr("Event title")
                        }
                        StyledTextField {
                            id: descriptionField
                            Layout.fillWidth: true
                            Layout.columnSpan: columns
                            placeholderText: qsTr("Description · optional")
                            maximumLength: 2000
                            Accessible.name: qsTr("Event description, optional")
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.columnSpan: columns
                            Item { Layout.fillWidth: true }
                            TextButton {
                                text: qsTr("Clear")
                                type: TextButton.Text
                                onClicked: root.clearForm()
                            }
                            TextButton {
                                text: root.editingId ? qsTr("Save changes") : qsTr("Add event")
                                enabled: titleField.text.trim().length > 0
                                    && root.validDate(dateField.text) !== ""
                                    && (!endDateField.text.trim() || root.validDate(endDateField.text) !== "")
                                onClicked: root.saveEvent()
                            }
                        }
                    }
                }

                SectionHeader {
                    title: qsTr("Saved events")
                    description: qsTr("%1 events").arg(root.allEvents.length)
                }

                SectionContainer {
                    Layout.fillWidth: true
                    visible: root.pendingDeleteId !== ""
                    RowLayout {
                        Layout.fillWidth: true
                        StyledText {
                            Layout.fillWidth: true
                            text: qsTr("Delete this event permanently?")
                            color: Colours.palette.m3error
                        }
                        TextButton {
                            text: qsTr("Cancel")
                            type: TextButton.Text
                            onClicked: root.pendingDeleteId = ""
                        }
                        TextButton {
                            text: qsTr("Delete")
                            onClicked: {
                                const removedId = root.pendingDeleteId;
                                Events.deleteEvent(removedId);
                                root.pendingDeleteId = "";
                                if (root.editingId === removedId)
                                    root.clearForm();
                            }
                        }
                    }
                }

                Repeater {
                    model: root.allEvents
                    SectionContainer {
                        required property var modelData
                        Layout.fillWidth: true
                        contentSpacing: Tokens.spacing.small

                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true
                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.title || qsTr("Untitled event")
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: `${modelData.date}${modelData.endDate ? ` – ${modelData.endDate}` : ""}${modelData.time ? ` · ${modelData.time}` : ""}`
                                    color: Colours.palette.m3onSurfaceVariant
                                    font.pointSize: Tokens.font.size.small
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    visible: !!modelData.description
                                    text: modelData.description || ""
                                    color: Colours.palette.m3onSurfaceVariant
                                    wrapMode: Text.WordWrap
                                }
                            }
                            IconButton {
                                icon: "edit"
                                Accessible.name: qsTr("Edit event")
                                onClicked: {
                                    root.editingId = String(modelData.id);
                                    dateField.text = modelData.date || "";
                                    endDateField.text = modelData.endDate || "";
                                    timeField.text = modelData.time || "";
                                    titleField.text = modelData.title || "";
                                    descriptionField.text = modelData.description || "";
                                }
                            }
                            IconButton {
                                icon: "delete"
                                Accessible.name: qsTr("Delete event")
                                onClicked: root.pendingDeleteId = String(modelData.id)
                            }
                        }
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: root.allEvents.length === 0
                    text: qsTr("No saved events yet.")
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }
}

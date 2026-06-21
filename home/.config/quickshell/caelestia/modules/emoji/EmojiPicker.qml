pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.services

Variants {
    model: Quickshell.screens

    PanelWindow {
        id: win

        required property ShellScreen modelData

        property int currentCat: 0
        property string query: ""
        readonly property var shown: {
            const cats = Emojis.categories;
            if (query.length > 0) {
                const q = query.toLowerCase();
                let r = [];
                for (let ci = 0; ci < cats.length; ci++)
                    for (const it of cats[ci].items)
                        if (it.n.indexOf(q) !== -1)
                            r.push(it);
                return r;
            }
            return cats[currentCat]?.items ?? [];
        }

        screen: modelData
        visible: Emojis.visible && (Hypr.monitorFor(modelData)?.focused ?? true)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "caelestia-emoji"

        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true

        onVisibleChanged: {
            if (visible) {
                query = "";
                currentCat = 0;
                search.text = "";
                search.forceActiveFocus();
            }
        }

        // dim + click-outside to close
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha("black", 0.35)

            MouseArea {
                anchors.fill: parent
                onClicked: Emojis.visible = false
            }
        }

        StyledRect {
            anchors.centerIn: parent
            implicitWidth: 780
            implicitHeight: 540
            radius: Tokens.rounding.large
            color: Colours.palette.m3surface

            MouseArea {
                anchors.fill: parent
            } // absorb clicks (don't close)

            Row {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.normal

                // category sidebar
                Column {
                    id: sidebar

                    width: 52
                    height: parent.height
                    spacing: Tokens.spacing.small

                    Repeater {
                        model: Emojis.categories

                        StyledRect {
                            id: catBtn

                            required property var modelData
                            required property int index

                            readonly property bool sel: win.query.length === 0 && win.currentCat === index

                            width: 48
                            height: 48
                            radius: Tokens.rounding.full
                            color: sel ? Colours.palette.m3primary : "transparent"

                            StateLayer {
                                radius: parent.radius
                                onClicked: {
                                    win.query = "";
                                    search.text = "";
                                    win.currentCat = catBtn.index;
                                }
                            }

                            MaterialIcon {
                                anchors.centerIn: parent
                                text: catBtn.modelData.icon
                                color: catBtn.sel ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                            }
                        }
                    }
                }

                // search + grid
                Column {
                    width: parent.width - sidebar.width - Tokens.spacing.normal
                    height: parent.height
                    spacing: Tokens.spacing.normal

                    StyledRect {
                        width: parent.width
                        implicitHeight: 44
                        radius: Tokens.rounding.full
                        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

                        MaterialIcon {
                            id: searchIcon

                            anchors.left: parent.left
                            anchors.leftMargin: Tokens.padding.large
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        TextInput {
                            id: search

                            anchors.left: searchIcon.right
                            anchors.leftMargin: Tokens.padding.normal
                            anchors.right: parent.right
                            anchors.rightMargin: Tokens.padding.large
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true
                            color: Colours.palette.m3onSurface
                            font.family: Tokens.font.family.sans
                            font.pointSize: Tokens.font.size.normal
                            selectionColor: Colours.palette.m3primary
                            onTextChanged: win.query = text.trim()

                            Keys.onEscapePressed: Emojis.visible = false
                            Keys.onReturnPressed: {
                                if (win.shown.length > 0)
                                    Emojis.copy(win.shown[0].e);
                            }

                            StyledText {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                visible: search.text.length === 0
                                text: qsTr("Search emoji…")
                                color: Colours.palette.m3onSurfaceVariant
                                font: search.font
                            }
                        }
                    }

                    GridView {
                        id: grid

                        width: parent.width
                        height: parent.height - 44 - Tokens.spacing.normal
                        clip: true
                        cellWidth: 60
                        cellHeight: 60
                        model: win.shown
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Item {
                            id: cell

                            required property var modelData

                            width: grid.cellWidth
                            height: grid.cellHeight

                            StyledRect {
                                anchors.fill: parent
                                anchors.margins: 3
                                radius: Tokens.rounding.normal
                                color: "transparent"

                                StateLayer {
                                    radius: parent.radius
                                    onClicked: Emojis.copy(cell.modelData.e)
                                }

                                StyledText {
                                    anchors.centerIn: parent
                                    text: cell.modelData.e
                                    font.pointSize: 24
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

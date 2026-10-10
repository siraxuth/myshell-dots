pragma ComponentBehavior: Bound

import "bluetooth"
import "network"
import "audio"
import "appearance"
import "taskbar"
import "notifications"
import "launcher"
import "dashboard"
import "display"
import "input"
import "events"
import "power"
import "storage"
import "widgets"
import QtQuick
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.settings

ClippingRectangle {
    id: root

    required property Session session

    readonly property bool initialOpeningComplete: layout.initialOpeningComplete

    // Keep the right-side content on its original surface while the outer
    // window and inner border use the container surface color.
    color: Colours.tPalette.m3surface
    clip: true
    focus: false
    activeFocusOnTab: false

    MouseArea {
        anchors.fill: parent
        z: -1
        onPressed: function (mouse) {
            root.focus = true;
            mouse.accepted = false;
        }
    }

    Connections {
        function onActiveIndexChanged(): void {
            root.focus = true;
        }

        target: root.session
    }

    Item {
        id: layout

        width: root.width
        implicitHeight: root.height * PaneRegistry.count
        height: implicitHeight
        property bool animationComplete: true
        property bool initialOpeningComplete: false
        property bool waitingForPane: false
        property int previousIndex: 0
        property int currentIndex: 0

        Component.onCompleted: {
            previousIndex = root.session.activeIndex;
            currentIndex = root.session.activeIndex;
        }

        y: -(waitingForPane ? previousIndex : root.session.activeIndex) * root.height
        clip: true

        Timer {
            id: animationDelayTimer

            interval: Tokens.anim.durations.small
            onTriggered: {
                layout.animationComplete = true;
            }
        }

        Timer {
            id: initialOpeningTimer

            interval: Tokens.anim.durations.small
            running: true
            onTriggered: {
                layout.initialOpeningComplete = true;
            }
        }

        Repeater {
            id: paneRepeater

            model: PaneRegistry.count

            Pane {
                required property int index

                width: root.width
                height: root.height
                y: index * root.height
                paneIndex: index
                componentPath: PaneRegistry.getByIndex(index).component
            }
        }

        Behavior on y {
            Anim {
                type: Anim.StandardSmall
            }
        }

        Connections {
            function onActiveIndexChanged(): void {
                const canWaitForPane = layout.animationComplete;
                layout.animationComplete = false;
                if (!layout.waitingForPane) {
                    if (canWaitForPane)
                        layout.previousIndex = layout.currentIndex;
                    layout.waitingForPane = canWaitForPane;
                }
                layout.currentIndex = root.session.activeIndex;
                animationDelayTimer.stop();

                if (layout.waitingForPane) {
                    Qt.callLater(() => {
                        const targetPane = paneRepeater.itemAt(layout.currentIndex);
                        if (!targetPane || targetPane.loaded) {
                            layout.waitingForPane = false;
                            animationDelayTimer.restart();
                        }
                    });
                } else {
                    animationDelayTimer.restart();
                }
            }

            target: root.session
        }
    }

    component Pane: Item {
        id: pane

        required property int paneIndex
        required property string componentPath
        readonly property string paneId: PaneRegistry.getByIndex(pane.paneIndex).id
        readonly property bool loaded: loader.item !== null

        function updateActive(): void {
            const diff = Math.abs(root.session.activeIndex - pane.paneIndex);
            const isTransitioningFrom = !layout.animationComplete
                && pane.paneIndex === layout.previousIndex;

            // Keep only the visible pane, its immediate neighbors, and the
            // outgoing pane during a transition. Previously every visited
            // pane stayed alive, so its bindings and live data kept updating.
            loader.active = diff <= 1 || isTransitioningFrom;
        }

        implicitWidth: root.width
        implicitHeight: root.height

        Loader {
            id: loader

            anchors.fill: parent
            asynchronous: true
            clip: false
            active: false

            Component.onCompleted: {
                Qt.callLater(pane.updateActive);
            }

            onActiveChanged: {
                if (active && !item) {
                    loader.setSource(pane.componentPath, {
                        "session": root.session
                    });
                }
            }

            onItemChanged: {
                if (item && layout.waitingForPane && pane.paneIndex === layout.currentIndex) {
                    layout.waitingForPane = false;
                    animationDelayTimer.restart();
                }
            }

            onStatusChanged: {
                if (status === Loader.Error && layout.waitingForPane
                        && pane.paneIndex === layout.currentIndex) {
                    layout.waitingForPane = false;
                    animationDelayTimer.restart();
                }
            }

        }

        Connections {
            function onActiveIndexChanged(): void {
                pane.updateActive();
            }

            target: root.session
        }

        Connections {
            function onInitialOpeningCompleteChanged(): void {
                pane.updateActive();
            }
            function onAnimationCompleteChanged(): void {
                pane.updateActive();
            }

            target: layout
        }
    }
}

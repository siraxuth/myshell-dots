pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import "sidebar"

Item {
    id: root

    required property ShellScreen screen
    readonly property int rounding: Tokens.rounding.large

    property alias active: session.active
    property alias navExpanded: session.navExpanded

    readonly property bool initialOpeningComplete: panes.initialOpeningComplete
    readonly property Session session: Session {
        id: session

        root: root
    }

    signal close

    implicitWidth: implicitHeight * Tokens.sizes.controlCenter.ratio + 250
    implicitHeight: screen.height * Tokens.sizes.controlCenter.heightMult

    GridLayout {
        anchors.fill: parent

        rowSpacing: 0
        columnSpacing: 0
        rows: 1
        columns: 2

        StyledRect {
            Layout.preferredWidth: root.width * 0.2
            Layout.minimumWidth: 0
            Layout.fillHeight: true

            topLeftRadius: root.rounding
            bottomLeftRadius: root.rounding
            implicitWidth: navRail.implicitWidth
            color: Colours.tPalette.m3surfaceContainer

            NavRail {
                id: navRail

                anchors.fill: parent

                screen: root.screen
                session: root.session
                initialOpeningComplete: root.initialOpeningComplete
            }
        }

        Panes {
            id: panes

            Layout.preferredWidth: root.width * 0.8
            Layout.fillWidth: true
            Layout.fillHeight: true

            topRightRadius: root.rounding
            bottomRightRadius: root.rounding
            session: root.session
        }
    }
}

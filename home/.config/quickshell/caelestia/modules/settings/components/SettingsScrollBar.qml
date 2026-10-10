import QtQuick
import QtQuick.Templates
import Caelestia.Config
import qs.components
import qs.services

// Qt's attached scrollbar owns the normalized position and native thumb drag.
ScrollBar {
    id: root

    required property Flickable flickable
    implicitWidth: Tokens.padding.small
    implicitHeight: Tokens.padding.small
    minimumSize: 0.04
    interactive: true

    SettingsScrollHandler {
        flickable: root.flickable
        parent: root
    }

    onPressedChanged: if (pressed && flickable) flickable.cancelFlick()

    contentItem: StyledRect {
        implicitWidth: root.implicitWidth
        implicitHeight: root.implicitHeight
        radius: Tokens.rounding.full
        color: Colours.palette.m3secondary
        opacity: root.size >= 1 ? 0 : root.pressed ? 1 : root.hovered ? 0.8
            : root.active || root.policy === ScrollBar.AlwaysOn ? 0.6 : 0

        Behavior on opacity { Anim {} }
    }
}

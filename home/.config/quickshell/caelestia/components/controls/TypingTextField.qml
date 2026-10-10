pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls

TextField {
    id: root

    property real typingOffset: 0

    transform: Translate {
        y: root.typingOffset
    }

    onTextChanged: {
        if (!activeFocus || text.length === 0) {
            typingOffset = 0;
            settleTimer.stop();
            return;
        }

        typingOffset = -4;
        settleTimer.restart();
    }

    Behavior on typingOffset {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: settleTimer

        interval: 120
        onTriggered: root.typingOffset = 0
    }
}

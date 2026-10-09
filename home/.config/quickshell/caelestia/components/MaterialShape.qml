import QtQuick

// Compact fallback for Material 3 shape indicators used by the calendar.
Rectangle {

    enum Shape {
        Sunny,
        Slanted,
        Oval,
        Pill,
        Triangle,
        Arrow,
        Diamond,
        Pentagon,
        Gem,
        Cookie4Sided,
        Cookie6Sided,
        Cookie7Sided,
        Cookie9Sided,
        Cookie12Sided,
        Clover4Leaf,
        SoftBurst,
        Ghostish
    }

    property int shape: MaterialShape.Sunny
    property real implicitSize: 0
    property var animationEasing
    property int animationDuration: 0

    implicitWidth: implicitSize
    implicitHeight: implicitSize
    radius: {
        if (shape === MaterialShape.Pill || shape === MaterialShape.Oval)
            return Math.min(width, height) / 2;

        if (shape === MaterialShape.Sunny || shape === MaterialShape.SoftBurst || shape === MaterialShape.Clover4Leaf)
            return Math.min(width, height) * 0.32;

        return Math.min(width, height) * 0.22;
    }
}
